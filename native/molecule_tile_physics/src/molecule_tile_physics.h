#ifndef ASTATINE_MOLECULE_TILE_PHYSICS_H
#define ASTATINE_MOLECULE_TILE_PHYSICS_H

#include <stdint.h>

#if defined(_WIN32)
#define MOLECULE_PHYSICS_EXPORT __declspec(dllexport)
#else
#define MOLECULE_PHYSICS_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  int32_t id;
  char formula[48];
  double seed;
  double x;
  double y;
  double velocity_x;
  double velocity_y;
  double scale;
  double thermal_time;
  double reaction_cooldown;
  double remaining_life;
  uint32_t color;
  int64_t created_at_milliseconds;
  int32_t motion;
  int32_t is_fluid;
} MoleculePhysicsParticle;

typedef struct {
  char metal_formula[48];
  char first_formula[48];
  char second_formula[48];
  double x;
  double y;
} MoleculePhysicsEvent;

typedef struct {
  int32_t status;
  int32_t particle_count;
  int32_t event_count;
  MoleculePhysicsParticle* particles;
  MoleculePhysicsEvent* events;
} MoleculePhysicsResult;

MOLECULE_PHYSICS_EXPORT MoleculePhysicsResult* molecule_physics_step(
    const MoleculePhysicsParticle* particles, int32_t particle_count,
    double width, double height, double delta_seconds, double temperature,
    int32_t burner_lit, uint64_t random_seed);

MOLECULE_PHYSICS_EXPORT void molecule_physics_result_free(
    MoleculePhysicsResult* result);

#ifdef __cplusplus
}
#endif

#endif
