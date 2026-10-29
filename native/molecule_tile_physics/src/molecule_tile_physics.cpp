#include "molecule_tile_physics.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <initializer_list>
#include <limits>
#include <new>
#include <random>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

constexpr int kSuspended = 0;
constexpr int kSolid = 1;
constexpr int kGas = 2;
constexpr int kPrecipitate = 3;
constexpr double kLiquidTop = 0.48;
constexpr double kLiquidBottom = 0.83;
constexpr double kMetalGravity = 1.8;
constexpr double kThermalDuration = 1.8;
constexpr double kShockwaveRadius = 0.22;
constexpr double kMaxJitterSpeed = 44.8;
constexpr size_t kMaxParticles = 65536;
constexpr size_t kMaxEvents = 16384;

using Particle = MoleculePhysicsParticle;
using Event = MoleculePhysicsEvent;

std::string formula_of(const Particle& particle) {
  const char* end =
      std::find(particle.formula, particle.formula + sizeof(particle.formula),
                '\0');
  return std::string(particle.formula, end);
}

void set_formula(Particle& particle, const std::string& formula) {
  std::memset(particle.formula, 0, sizeof(particle.formula));
  const size_t length = std::min(formula.size(), sizeof(particle.formula) - 1);
  std::memcpy(particle.formula, formula.data(), length);
}

void set_text(char* destination, size_t capacity, const std::string& value) {
  std::memset(destination, 0, capacity);
  const size_t length = std::min(value.size(), capacity - 1);
  std::memcpy(destination, value.data(), length);
}

bool one_of(const std::string& value,
            std::initializer_list<const char*> choices) {
  for (const char* choice : choices) {
    if (value == choice) return true;
  }
  return false;
}

class Simulator {
 public:
  Simulator(const MoleculePhysicsParticle* input, int32_t count, double width,
            double height, double delta_seconds, double temperature,
            bool burner_lit, uint64_t seed)
      : particles_(input, input + count),
        width_(width),
        height_(height),
        dt_(std::min(delta_seconds, 1.0 / 20.0)),
        temperature_(temperature),
        burner_lit_(burner_lit),
        original_count_(static_cast<size_t>(count)),
        rng_(seed),
        removed_(static_cast<size_t>(count), false) {}

  void run() {
    update_particles();
    if (burner_lit_ && temperature_ > 300) run_thermal_reactions();
    run_metal_reactions();
    run_collisions();
    compact_particles();
  }

  const std::vector<Particle>& particles() const { return particles_; }
  const std::vector<Event>& events() const { return events_; }
  bool overflowed() const { return overflow_; }

 private:
  double random_double() {
    return std::generate_canonical<double, 53>(rng_);
  }

  bool random_bool() { return (rng_() & 1U) != 0; }

  double now_milliseconds() const {
    using namespace std::chrono;
    return static_cast<double>(
        duration_cast<milliseconds>(system_clock::now().time_since_epoch())
            .count());
  }

  std::string formula(size_t index) const { return formula_of(particles_[index]); }

  bool has_formula(const std::string& value) const {
    return std::any_of(particles_.begin(), particles_.end(),
                       [&](const Particle& particle) {
                         return formula_of(particle) == value;
                       });
  }

  void mark_removed(size_t index) {
    if (index < removed_.size()) removed_[index] = true;
  }

  bool is_removed(size_t index) const {
    return index < removed_.size() && removed_[index];
  }

  void append(Particle particle) {
    if (particles_.size() >= kMaxParticles) {
      overflow_ = true;
      return;
    }
    particles_.push_back(particle);
    removed_.push_back(false);
  }

  Event event(const std::string& metal, size_t first, size_t second) const {
    Event result{};
    set_text(result.metal_formula, sizeof(result.metal_formula), metal);
    set_text(result.first_formula, sizeof(result.first_formula),
             formula(first));
    set_text(result.second_formula, sizeof(result.second_formula),
             formula(second));
    result.x = (particles_[first].x + particles_[second].x) / 2;
    result.y = (particles_[first].y + particles_[second].y) / 2;
    return result;
  }

  void record_event(const Event& value) {
    if (events_.size() >= kMaxEvents) {
      overflow_ = true;
      return;
    }
    events_.push_back(value);
  }

  void spawn_product(const std::string& name, int motion, size_t source,
                     double x, double y, bool fluid = false,
                     double velocity_y = 0,
                     double remaining_life =
                         std::numeric_limits<double>::infinity()) {
    Particle product{};
    set_formula(product, name);
    product.seed = random_double();
    product.x = x;
    product.y = y;
    product.velocity_x = particles_[source].velocity_x;
    product.velocity_y = motion == kGas ? velocity_y
                                        : particles_[source].velocity_y;
    product.scale = 1;
    product.remaining_life = remaining_life;
    product.color = particles_[source].color;
    product.created_at_milliseconds =
        static_cast<int64_t>(now_milliseconds());
    product.motion = motion;
    product.is_fluid = fluid ? 1 : 0;
    append(product);
  }

  void spawn_gas(size_t source, double x, double y,
                 const std::string& name = "H2", double velocity_y = -0.18) {
    spawn_product(name, kGas, source, x, y, false, velocity_y, 5.5);
  }

  void make_event_products(const Event& value, size_t source) {
    std::string hydroxide = "NaOH";
    const std::string metal(value.metal_formula);
    if (metal == "K") hydroxide = "KOH";
    if (metal == "Ba") hydroxide = "Ba(OH)2";
    if (metal == "Ca") hydroxide = "Ca(OH)2";
    spawn_product(hydroxide, kSuspended, source, value.x, value.y, true, 0.16);
    spawn_gas(source, value.x, value.y);
  }

  bool overlaps(size_t first, size_t second) const {
    return std::abs(particles_[first].x - particles_[second].x) * width_ <=
               35 &&
           std::abs(particles_[first].y - particles_[second].y) * height_ <=
               25;
  }

  void keep_inside(Particle& particle, bool fluid) {
    const double left = 0.22 + particle.y * 0.10 + 0.025;
    const double right = 0.78 - particle.y * 0.10 - 0.025;
    if (particle.x < left) {
      particle.x = left;
      particle.velocity_x = std::abs(particle.velocity_x) * 0.52;
    } else if (particle.x > right) {
      particle.x = right;
      particle.velocity_x = -std::abs(particle.velocity_x) * 0.52;
    }
    const double floor = fluid ? kLiquidBottom : 0.84;
    const double ceiling = fluid ? kLiquidTop : 0.14;
    if (particle.y > floor) {
      particle.y = floor;
      if (particle.motion == kSolid || particle.motion == kPrecipitate) {
        particle.velocity_y = 0;
      } else {
        particle.velocity_y = -std::abs(particle.velocity_y) * 0.28;
      }
    } else if (particle.y < ceiling) {
      particle.y = ceiling;
      particle.velocity_y = std::abs(particle.velocity_y) * 0.28;
    }
  }

  void update_particles() {
    const double normalized_temperature =
        (std::clamp(temperature_, 0.0, 100.0)) / 100.0;
    const double jitter_speed =
        kMaxJitterSpeed * normalized_temperature * normalized_temperature;
    for (size_t index = 0; index < original_count_; ++index) {
      Particle& particle = particles_[index];
      particle.thermal_time = std::max(0.0, particle.thermal_time - dt_);
      particle.reaction_cooldown =
          std::max(0.0, particle.reaction_cooldown - dt_);
      particle.remaining_life -= dt_;
      if (particle.motion == kGas) {
        particle.velocity_y -= 0.06 * dt_;
        particle.velocity_x += (random_double() - 0.5) * 0.12 * dt_;
        particle.velocity_x *= std::pow(0.998, dt_ * 60);
        particle.x += particle.velocity_x * dt_;
        particle.y += particle.velocity_y * dt_;
        const double left = 0.22 + particle.y * 0.10 + 0.025;
        const double right = 0.78 - particle.y * 0.10 - 0.025;
        if (particle.x < left) {
          particle.x = left;
          particle.velocity_x = std::abs(particle.velocity_x) * 0.52;
        } else if (particle.x > right) {
          particle.x = right;
          particle.velocity_x = -std::abs(particle.velocity_x) * 0.52;
        }
      } else if (particle.is_fluid) {
        if (jitter_speed == 0) {
          particle.velocity_x = particle.velocity_y = 0;
        } else {
          const double impulse = std::sqrt(dt_);
          particle.velocity_x = std::clamp(
              particle.velocity_x +
                  (random_double() - 0.5) * jitter_speed * impulse,
              -1.3, 1.3);
          particle.velocity_y = std::clamp(
              particle.velocity_y +
                  (random_double() - 0.5) * jitter_speed * impulse,
              -0.8, 0.8);
          const double damping = std::pow(0.965, dt_ * 60);
          particle.velocity_x *= damping;
          particle.velocity_y *= damping;
          particle.x += particle.velocity_x * dt_;
          particle.y += particle.velocity_y * dt_;
          keep_inside(particle, true);
        }
      } else if (particle.motion == kSolid ||
                 particle.motion == kPrecipitate) {
        const std::string name = formula(index);
        if (name == "K" || name == "Na") {
          particle.velocity_y += kMetalGravity * dt_;
          particle.velocity_x += (random_double() - 0.5) * 0.18 * dt_;
          particle.velocity_x *= std::pow(0.992, dt_ * 60);
        } else {
          if (particle.y >= 0.84) {
            particle.y = 0.84;
            particle.velocity_x = particle.velocity_y = 0;
          } else {
            particle.velocity_y += 1.2 * dt_;
          }
        }
        particle.x += particle.velocity_x * dt_;
        particle.y += particle.velocity_y * dt_;
        keep_inside(particle, false);
      } else {
        particle.velocity_y += 0.12 * dt_;
        particle.velocity_x *= std::pow(0.98, dt_ * 60);
        particle.x += particle.velocity_x * dt_;
        particle.y += particle.velocity_y * dt_;
        keep_inside(particle, true);
      }
      if (particle.remaining_life <= 0 ||
          (particle.motion == kGas && particle.y < 0.08)) {
        mark_removed(index);
      }
    }
  }

  void run_thermal_reactions() {
    for (size_t index = 0; index < original_count_; ++index) {
      if (is_removed(index) || particles_[index].reaction_cooldown > 0) continue;
      const std::string name = formula(index);
      std::vector<std::pair<std::string, int>> products;
      if (name == "CaCO3") {
        products = {{"CaO", kSolid}, {"CO2", kGas}};
      } else if (name == "KMnO4") {
        products = {{"K2MnO4", kSuspended}, {"MnO2", kPrecipitate},
                    {"O2", kGas}};
      } else if (name == "Cu(OH)2") {
        products = {{"CuO", kSolid}, {"H2O", kSuspended}};
      }
      if (products.empty()) continue;
      const Event value = event("", index, index);
      Event thermal_event = value;
      set_text(thermal_event.second_formula, sizeof(value.second_formula),
               "HEAT");
      record_event(thermal_event);
      mark_removed(index);
      for (const auto& product : products) {
        spawn_product(product.first, product.second, index, value.x, value.y,
                      product.first == "K2MnO4" || product.first == "H2O",
                      product.second == kGas ? -0.12 : 0);
      }
    }
  }

  bool reacts_with_water(const std::string& name) const {
    return one_of(name, {"K", "Na", "Ca", "Ba"}) ||
           (temperature_ >= 70 &&
            one_of(name, {"Mg", "Al", "Zn", "Fe"}));
  }

  std::string hot_water_product(const std::string& name) const {
    if (name == "Mg") return "Mg(OH)2";
    if (name == "Al") return "Al(OH)3";
    if (name == "Zn") return "Zn(OH)2";
    if (name == "Fe") return "Fe(OH)2";
    return "";
  }

  bool is_reactive_acid_metal(const std::string& name) const {
    return one_of(name, {"K", "Na", "Mg", "Al", "Zn", "Fe", "Pb", "Ca",
                         "Ba"});
  }

  std::string metal_acid_salt(const std::string& metal,
                              const std::string& acid) const {
    if (acid == "HCl") {
      if (metal == "K") return "KCl";
      if (metal == "Na") return "NaCl";
      if (metal == "Mg") return "MgCl2";
      if (metal == "Al") return "AlCl3";
      if (metal == "Zn") return "ZnCl2";
      if (metal == "Fe") return "FeCl2";
      if (metal == "Pb") return "PbCl2";
      if (metal == "Ca") return "CaCl2";
      if (metal == "Ba") return "BaCl2";
      return "";
    }
    if (metal == "K") return "K2SO4";
    if (metal == "Na") return "Na2SO4";
    if (metal == "Mg") return "MgSO4";
    if (metal == "Al") return "Al2(SO4)3";
    if (metal == "Zn") return "ZnSO4";
    if (metal == "Fe") return "FeSO4";
    if (metal == "Pb") return "PbSO4";
    if (metal == "Ca") return "CaSO4";
    if (metal == "Ba") return "BaSO4";
    return "";
  }

  void run_metal_reactions() {
    const double magnesium_cooldown =
        0.55 - ((std::clamp(temperature_, 70.0, 100.0) - 70) / 30) * 0.45;
    for (size_t metal = 0; metal < original_count_; ++metal) {
      const std::string metal_name = formula(metal);
      if (!is_reactive_acid_metal(metal_name) || is_removed(metal) ||
          particles_[metal].scale <= 0.18 ||
          particles_[metal].reaction_cooldown > 0) {
        continue;
      }
      for (size_t water = 0; water < original_count_; ++water) {
        if (formula(water) != "H2O" || !particles_[water].is_fluid ||
            is_removed(water) || !reacts_with_water(metal_name) ||
            !overlaps(metal, water)) {
          continue;
        }
        mark_removed(water);
        const Event value = event(metal_name, metal, water);
        record_event(value);
        const std::string product = hot_water_product(metal_name);
        if (!product.empty()) {
          particles_[metal].reaction_cooldown = magnesium_cooldown;
          particles_[metal].scale =
              std::max(0.18, particles_[metal].scale - 0.08);
          spawn_product(product, kPrecipitate, metal, value.x, value.y);
          spawn_gas(metal, value.x, value.y);
          if (one_of(metal_name, {"K", "Na", "Ca", "Ba"})) {
            apply_shockwave(metal, value, 1);
          }
        } else {
          particles_[metal].reaction_cooldown = 0.28;
          particles_[metal].scale =
              std::max(0.18, particles_[metal].scale - 0.12);
          make_event_products(value, metal);
          apply_shockwave(metal, value, 1);
        }
        if (particles_[metal].scale <= 0.18) mark_removed(metal);
        break;
      }
      if (is_removed(metal) || particles_[metal].reaction_cooldown > 0) continue;
      for (size_t acid = 0; acid < original_count_; ++acid) {
        const std::string acid_name = formula(acid);
        if (is_removed(acid) || !is_reactive_acid_metal(metal_name) ||
            !one_of(acid_name, {"HCl", "H2SO4"}) ||
            !overlaps(metal, acid)) {
          continue;
        }
        std::string salt;
        if (metal_name == "Fe" && acid_name == "HCl" &&
            temperature_ >= 80) {
          salt = "FeCl3";
        } else {
          salt = metal_acid_salt(metal_name, acid_name);
        }
        if (salt.empty()) continue;
        const Event value = event(metal_name, metal, acid);
        record_event(value);
        mark_removed(acid);
        particles_[metal].reaction_cooldown = 0.3;
        particles_[metal].scale =
            std::max(0.18, particles_[metal].scale - 0.12);
        const bool precipitate = salt == "PbCl2" || salt == "PbSO4";
        spawn_product(salt, precipitate ? kPrecipitate : kSuspended, metal,
                      value.x, value.y, !precipitate);
        spawn_gas(metal, value.x, value.y);
        if (particles_[metal].scale <= 0.18) mark_removed(metal);
        break;
      }
    }
  }

  void run_collisions();
  bool react_pair(size_t first, size_t second);
  bool react_special_metal_pair(size_t first, size_t second);
  bool react_hydrolysis(size_t first, size_t second);
  bool react_basic_oxide_water(size_t first, size_t second);
  void consume(size_t first, size_t second);
  void apply_shockwave(size_t metal, const Event& value, double impulse_scale);
  void compact_particles();

  std::vector<Particle> particles_;
  std::vector<Event> events_;
  double width_;
  double height_;
  double dt_;
  double temperature_;
  bool burner_lit_;
  size_t original_count_;
  std::mt19937_64 rng_;
  std::vector<bool> removed_;
  bool overflow_ = false;
};

void Simulator::run_collisions() {
  std::unordered_map<uint64_t, std::vector<size_t>> buckets;
  std::vector<std::pair<int32_t, int32_t>> cells(original_count_);
  for (size_t index = 0; index < original_count_; ++index) {
    const Particle& particle = particles_[index];
    const int32_t cell_x =
        static_cast<int32_t>(std::floor(particle.x * width_ / 35));
    const int32_t cell_y =
        static_cast<int32_t>(std::floor(particle.y * height_ / 25));
    cells[index] = {cell_x, cell_y};
    const uint64_t key =
        (static_cast<uint64_t>(static_cast<uint32_t>(cell_x)) << 32) |
        static_cast<uint32_t>(cell_y);
    buckets[key].push_back(index);
  }
  for (size_t first = 0; first < original_count_; ++first) {
    if (is_removed(first) || particles_[first].reaction_cooldown > 0) continue;
    bool reacted = false;
    for (int32_t dx = -1; dx <= 1 && !reacted; ++dx) {
      for (int32_t dy = -1; dy <= 1 && !reacted; ++dy) {
        const int32_t cell_x = cells[first].first + dx;
        const int32_t cell_y = cells[first].second + dy;
        const uint64_t key =
            (static_cast<uint64_t>(static_cast<uint32_t>(cell_x)) << 32) |
            static_cast<uint32_t>(cell_y);
        const auto found = buckets.find(key);
        if (found == buckets.end()) continue;
        for (size_t second : found->second) {
          if (second <= first || is_removed(second) ||
              particles_[second].reaction_cooldown > 0 ||
              !overlaps(first, second)) {
            continue;
          }
          if (react_pair(first, second)) {
            reacted = true;
            break;
          }
        }
      }
    }
  }
}

void Simulator::compact_particles() {
  std::vector<Particle> alive;
  alive.reserve(particles_.size());
  for (size_t index = 0; index < particles_.size(); ++index) {
    if (!is_removed(index)) alive.push_back(particles_[index]);
  }
  particles_.swap(alive);
}

void Simulator::consume(size_t first, size_t second) {
  mark_removed(first);
  mark_removed(second);
  particles_[first].reaction_cooldown = 0.35;
  particles_[second].reaction_cooldown = 0.35;
}

void Simulator::apply_shockwave(size_t metal, const Event& value,
                                double impulse_scale) {
  for (Particle& particle : particles_) {
    const double dx = (particle.x - value.x) * width_;
    const double dy = (particle.y - value.y) * height_;
    const double distance = std::sqrt(dx * dx + dy * dy);
    if (distance > kShockwaveRadius * std::min(width_, height_)) continue;
    const double direction_x = distance == 0 ? 0 : dx / distance;
    const double direction_y = distance == 0 ? -0.35 : dy / distance;
    particle.velocity_x += direction_x * 0.65 * impulse_scale;
    particle.velocity_y += direction_y * 0.65 * impulse_scale;
    particle.thermal_time = kThermalDuration;
  }
  const double dx = particles_[metal].x - value.x;
  const double dy = particles_[metal].y - value.y;
  const double magnitude = std::sqrt(dx * dx + dy * dy);
  const double direction_x =
      magnitude == 0 ? (random_bool() ? 1.0 : -1.0) : dx / magnitude;
  const double direction_y = magnitude == 0 ? -0.4 : dy / magnitude;
  particles_[metal].velocity_x +=
      direction_x * (0.55 + random_double() * 0.35) * impulse_scale;
  particles_[metal].velocity_y +=
      (direction_y * (0.45 + random_double() * 0.3) - 0.45) * impulse_scale;
  particles_[metal].thermal_time = kThermalDuration;
}

bool Simulator::react_pair(size_t first, size_t second) {
  if (react_special_metal_pair(first, second)) return true;
  if (react_basic_oxide_water(first, second)) return true;
  if (react_hydrolysis(first, second)) return true;

  const std::string a = formula(first);
  const std::string b = formula(second);
  size_t acid = a == "HCl" ? first : (b == "HCl" ? second : particles_.size());
  size_t aluminate =
      a == "NaAlO2" ? first : (b == "NaAlO2" ? second : particles_.size());
  size_t aluminium_hydroxide =
      a == "Al(OH)3" ? first
                     : (b == "Al(OH)3" ? second : particles_.size());
  if (acid < particles_.size() && aluminate < particles_.size()) {
    const Event value = event("", acid, aluminate);
    consume(acid, aluminate);
    spawn_product("Al(OH)3", kPrecipitate, aluminate, value.x, value.y);
    spawn_product("NaCl", kSuspended, acid, value.x, value.y, true);
    record_event(value);
    return true;
  }
  if (acid < particles_.size() && aluminium_hydroxide < particles_.size()) {
    const Event value = event("", acid, aluminium_hydroxide);
    consume(acid, aluminium_hydroxide);
    spawn_product("AlCl3", kSuspended, aluminium_hydroxide, value.x, value.y,
                  true);
    spawn_product("H2O", kSuspended, acid, value.x, value.y, true);
    record_event(value);
    return true;
  }

  auto is_hydroxide = [](const std::string& value) {
    return one_of(value, {"NaOH", "KOH", "Ba(OH)2", "Ca(OH)2"});
  };
  auto is_salt = [](const std::string& value) {
    return one_of(value, {"CuSO4", "FeCl3", "FeSO4", "FeCl2", "AlCl3",
                          "Al2(SO4)3", "ZnSO4", "ZnCl2"});
  };
  size_t hydroxide = is_hydroxide(a) && is_salt(b)
                         ? first
                         : (is_hydroxide(b) && is_salt(a) ? second
                                                         : particles_.size());
  size_t salt = hydroxide == first ? second
                                   : (hydroxide == second ? first
                                                          : particles_.size());
  if (hydroxide < particles_.size()) {
    const std::string base = formula(hydroxide);
    std::string cation;
    if (base == "NaOH") cation = "Na";
    if (base == "KOH") cation = "K";
    if (base == "Ba(OH)2") cation = "Ba";
    if (base == "Ca(OH)2") cation = "Ca";
    const std::string salt_name = formula(salt);
    std::string precipitate;
    if (salt_name == "CuSO4") precipitate = "Cu(OH)2";
    if (salt_name == "FeCl3") precipitate = "Fe(OH)3";
    if (salt_name == "FeSO4" || salt_name == "FeCl2")
      precipitate = "Fe(OH)2";
    if ((salt_name == "AlCl3" || salt_name == "Al2(SO4)3") &&
        !cation.empty())
      precipitate = "Al(OH)3";
    if (salt_name == "ZnSO4" || salt_name == "ZnCl2")
      precipitate = "Zn(OH)2";
    if (cation.empty() || precipitate.empty()) return false;
    const bool divalent = cation == "Ba" || cation == "Ca";
    std::string byproduct;
    if (salt_name.find("SO4") != std::string::npos) {
      byproduct = divalent ? cation + "SO4" : cation + "2SO4";
    } else if (salt_name.find("Cl") != std::string::npos) {
      byproduct = divalent ? cation + "Cl2" : cation + "Cl";
    }
    if (byproduct.empty()) return false;
    const Event value = event("", hydroxide, salt);
    consume(first, second);
    spawn_product(precipitate, kPrecipitate, hydroxide, value.x, value.y);
    spawn_product(byproduct, kSuspended, salt, value.x, value.y, true);
    record_event(value);
    return true;
  }

  const bool aluminate_reaction =
      (a == "Al(OH)3" && b == "NaOH") ||
      (b == "Al(OH)3" && a == "NaOH");
  if (aluminate_reaction) {
    const size_t al = a == "Al(OH)3" ? first : second;
    const size_t naoh = al == first ? second : first;
    const Event value = event("", al, naoh);
    consume(al, naoh);
    spawn_product("NaAlO2", kSuspended, al, value.x, value.y, true);
    spawn_product("H2O", kSuspended, naoh, value.x, value.y, true);
    record_event(value);
    return true;
  }

  const size_t gas = one_of(a, {"CO2", "SO2"})
                         ? first
                         : (one_of(b, {"CO2", "SO2"}) ? second
                                                       : particles_.size());
  if (gas == particles_.size()) return false;
  const size_t other = gas == first ? second : first;
  const std::string gas_name = formula(gas);
  const std::string other_name = formula(other);
  const bool base = one_of(other_name, {"Ca(OH)2", "Ba(OH)2"});
  const bool carbonate_or_sulfite =
      one_of(other_name, {"CaCO3", "BaCO3", "CaSO3", "BaSO3"});
  if (base) {
    const std::string cation = other_name.rfind("Ba", 0) == 0 ? "Ba" : "Ca";
    const std::string product =
        cation + (gas_name == "CO2" ? "CO3" : "SO3");
    const Event value = event("", gas, other);
    consume(gas, other);
    spawn_product(product, kPrecipitate, other, value.x, value.y);
    spawn_product("H2O", kSuspended, other, value.x, value.y, true);
    record_event(value);
    return true;
  }
  const bool matches_gas =
      (gas_name == "CO2" && other_name.size() >= 3 &&
       other_name.substr(other_name.size() - 3) == "CO3") ||
      (gas_name == "SO2" && other_name.size() >= 3 &&
       other_name.substr(other_name.size() - 3) == "SO3");
  if (carbonate_or_sulfite && matches_gas && has_formula("H2O")) {
    const std::string cation = other_name.rfind("Ba", 0) == 0 ? "Ba" : "Ca";
    const std::string product = gas_name == "CO2" ? cation + "(HCO3)2"
                                                  : cation + "(HSO3)2";
    const Event value = event("", gas, other);
    consume(gas, other);
    spawn_product(product, kSuspended, other, value.x, value.y, true);
    record_event(value);
    return true;
  }
  return false;
}

bool Simulator::react_special_metal_pair(size_t first, size_t second) {
  const std::string a = formula(first);
  const std::string b = formula(second);
  const size_t iron = a == "Fe" ? first : (b == "Fe" ? second : particles_.size());
  const size_t chlorine =
      a == "Cl2" ? first : (b == "Cl2" ? second : particles_.size());
  if (iron < particles_.size() && chlorine < particles_.size()) {
    const Event value = event("Fe", iron, chlorine);
    consume(iron, chlorine);
    spawn_product("FeCl3", kSuspended, iron, value.x, value.y, true);
    record_event(value);
    return true;
  }
  const size_t acid = a == "HCl" ? first : (b == "HCl" ? second : particles_.size());
  if (iron < particles_.size() && acid < particles_.size() &&
      temperature_ >= 80) {
    const Event value = event("Fe", iron, acid);
    mark_removed(acid);
    spawn_product("FeCl3", kSuspended, iron, value.x, value.y, true);
    for (int i = 0; i < 3; ++i) spawn_gas(iron, value.x, value.y);
    record_event(value);
    return true;
  }

  const size_t copper =
      a == "Cu" ? first : (b == "Cu" ? second : particles_.size());
  const size_t silver_nitrate =
      a == "AgNO3" ? first : (b == "AgNO3" ? second : particles_.size());
  if (copper < particles_.size() && silver_nitrate < particles_.size()) {
    const Event value = event("Cu", copper, silver_nitrate);
    mark_removed(silver_nitrate);
    spawn_product("Cu(NO3)2", kSuspended, silver_nitrate, value.x, value.y,
                  true);
    spawn_product("Ag", kSuspended, copper, particles_[copper].x - 0.012,
                  particles_[copper].y);
    spawn_product("Ag", kSuspended, copper, particles_[copper].x + 0.012,
                  particles_[copper].y);
    record_event(value);
    return true;
  }

  const size_t sulfuric =
      a == "H2SO4" ? first : (b == "H2SO4" ? second : particles_.size());
  if (copper >= particles_.size() || sulfuric >= particles_.size() ||
      temperature_ < 80) {
    return false;
  }
  const Event value = event("Cu", copper, sulfuric);
  mark_removed(sulfuric);
  spawn_product("CuSO4", kSuspended, sulfuric, value.x, value.y, true);
  spawn_gas(copper, value.x, value.y, "SO2", -0.10);
  spawn_product("H2O", kSuspended, sulfuric, value.x, value.y, true);
  record_event(value);
  return true;
}

bool Simulator::react_basic_oxide_water(size_t first, size_t second) {
  const std::string a = formula(first);
  const std::string b = formula(second);
  const size_t oxide = a == "H2O" ? second : (b == "H2O" ? first : particles_.size());
  if (oxide >= particles_.size() ||
      !one_of(formula(oxide), {"Na2O", "K2O", "CaO", "BaO"})) {
    return false;
  }
  const size_t water = oxide == first ? second : first;
  if (!particles_[water].is_fluid) return false;
  std::string product = formula(oxide) == "Na2O"   ? "NaOH"
                       : formula(oxide) == "K2O"   ? "KOH"
                       : formula(oxide) == "CaO"   ? "Ca(OH)2"
                                                    : "Ba(OH)2";
  const Event value = event("", oxide, water);
  consume(oxide, water);
  spawn_product(product, kSuspended, oxide, value.x, value.y, true);
  apply_shockwave(oxide, value, 0.55);
  record_event(value);
  return true;
}

bool Simulator::react_hydrolysis(size_t first, size_t second) {
  const std::string a = formula(first);
  const std::string b = formula(second);
  const size_t water = a == "H2O" ? first : (b == "H2O" ? second : particles_.size());
  if (water >= particles_.size()) return false;
  const size_t reagent = water == first ? second : first;
  const std::string name = formula(reagent);
  if (name == "Mg" ||
      !one_of(name, {"AlCl3", "FeCl3", "Al2(SO4)3", "Na2CO3", "CH3COONa",
                     "NH4Cl", "CaC2", "Al4C3", "Ca3P2"})) {
    return false;
  }
  if ((name == "CaC2" || name == "Al4C3") && temperature_ < 60) return false;
  const int stoichiometry =
      name == "CaC2" ? 2 : (name == "Al4C3" ? 12 : (name == "Ca3P2" ? 6 : 1));
  std::vector<std::pair<double, size_t>> candidates;
  for (size_t index = 0; index < particles_.size(); ++index) {
    if (formula(index) != "H2O" || !particles_[index].is_fluid ||
        is_removed(index)) {
      continue;
    }
    const double dx = (particles_[index].x - particles_[reagent].x) * width_;
    const double dy = (particles_[index].y - particles_[reagent].y) * height_;
    const double distance = std::sqrt(dx * dx + dy * dy);
    if (distance <= kShockwaveRadius * std::min(width_, height_) * 1.5) {
      candidates.emplace_back(distance, index);
    }
  }
  if (static_cast<int>(candidates.size()) < stoichiometry) return false;
  std::stable_sort(candidates.begin(), candidates.end(),
                   [](const auto& left, const auto& right) {
                     return left.first < right.first;
                   });
  const Event value = event("", reagent, water);
  consume(reagent, candidates.front().second);
  for (int i = 1; i < stoichiometry; ++i) mark_removed(candidates[i].second);

  if (name == "CaC2") {
    spawn_product("Ca(OH)2", kPrecipitate, reagent, value.x, value.y);
    spawn_gas(reagent, value.x, value.y, "C2H2", -0.12);
  } else if (name == "Al4C3") {
    for (int i = 0; i < 4; ++i)
      spawn_product("Al(OH)3", kPrecipitate, reagent, value.x, value.y);
    for (int i = 0; i < 3; ++i)
      spawn_gas(reagent, value.x, value.y, "CH4", -0.12);
  } else if (name == "Ca3P2") {
    for (int i = 0; i < 3; ++i)
      spawn_product("Ca(OH)2", kPrecipitate, reagent, value.x, value.y);
    for (int i = 0; i < 2; ++i)
      spawn_gas(reagent, value.x, value.y, "PH3", -0.12);
  } else if (name == "Na2CO3") {
    spawn_product("NaHCO3", kSuspended, reagent, value.x, value.y, true);
    spawn_product("NaOH", kSuspended, reagent, value.x, value.y, true);
  } else if (name == "CH3COONa") {
    spawn_product("CH3COOH", kSuspended, reagent, value.x, value.y, true);
    spawn_product("NaOH", kSuspended, reagent, value.x, value.y, true);
  } else if (name == "NH4Cl") {
    spawn_product("NH4OH", kSuspended, reagent, value.x, value.y, true);
    spawn_product("HCl", kSuspended, reagent, value.x, value.y, true);
  } else {
    spawn_product(name == "FeCl3" ? "Fe(OH)3" : "Al(OH)3", kPrecipitate,
                  reagent, value.x, value.y);
    spawn_product(name == "Al2(SO4)3" ? "H2SO4" : "HCl", kSuspended,
                  reagent, value.x, value.y, true);
  }
  if (one_of(name, {"CaC2", "Al4C3", "Ca3P2"})) {
    const double scale =
        0.75 + ((std::clamp(temperature_, 60.0, 100.0) - 60) / 40) * 0.8;
    apply_shockwave(reagent, value, scale);
    particles_[reagent].thermal_time = kThermalDuration;
  }
  record_event(value);
  return true;
}

}  // namespace

extern "C" MOLECULE_PHYSICS_EXPORT MoleculePhysicsResult*
molecule_physics_step(const MoleculePhysicsParticle* input, int32_t count,
                      double width, double height, double delta_seconds,
                      double temperature, int32_t burner_lit,
                      uint64_t random_seed) {
  auto* result = new (std::nothrow) MoleculePhysicsResult{};
  if (result == nullptr) return nullptr;
  if (count < 0 || (count > 0 && input == nullptr) || !std::isfinite(width) ||
      !std::isfinite(height) || width <= 0 || height <= 0 ||
      !std::isfinite(delta_seconds) || delta_seconds <= 0 ||
      !std::isfinite(temperature) ||
      static_cast<size_t>(count) > kMaxParticles) {
    result->status = 1;
    return result;
  }
  try {
    Simulator simulator(input, count, width, height, delta_seconds, temperature,
                        burner_lit != 0, random_seed);
    simulator.run();
    if (simulator.overflowed()) {
      result->status = 4;
      return result;
    }
    const auto& particles = simulator.particles();
    const auto& events = simulator.events();
    result->particle_count = static_cast<int32_t>(particles.size());
    result->event_count = static_cast<int32_t>(events.size());
    if (!particles.empty()) {
      result->particles = new (std::nothrow) MoleculePhysicsParticle[particles.size()];
      if (result->particles == nullptr) {
        result->status = 2;
        return result;
      }
      std::copy(particles.begin(), particles.end(), result->particles);
    }
    if (!events.empty()) {
      result->events = new (std::nothrow) MoleculePhysicsEvent[events.size()];
      if (result->events == nullptr) {
        result->status = 2;
        return result;
      }
      std::copy(events.begin(), events.end(), result->events);
    }
  } catch (...) {
    result->status = 3;
  }
  return result;
}

extern "C" MOLECULE_PHYSICS_EXPORT void molecule_physics_result_free(
    MoleculePhysicsResult* result) {
  if (result == nullptr) return;
  delete[] result->particles;
  delete[] result->events;
  delete result;
}
