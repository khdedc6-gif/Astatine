import 'dart:ffi' as ffi;

final class MoleculePhysicsParticle extends ffi.Struct {
  @ffi.Int32()
  external int id;

  @ffi.Array<ffi.Uint8>(48)
  external ffi.Array<ffi.Uint8> formula;

  @ffi.Double()
  external double seed;

  @ffi.Double()
  external double x;

  @ffi.Double()
  external double y;

  @ffi.Double()
  external double velocity_x;

  @ffi.Double()
  external double velocity_y;

  @ffi.Double()
  external double scale;

  @ffi.Double()
  external double thermal_time;

  @ffi.Double()
  external double reaction_cooldown;

  @ffi.Double()
  external double remaining_life;

  @ffi.Uint32()
  external int color;

  @ffi.Int64()
  external int created_at_milliseconds;

  @ffi.Int32()
  external int motion;

  @ffi.Int32()
  external int is_fluid;
}

final class MoleculePhysicsEvent extends ffi.Struct {
  @ffi.Array<ffi.Uint8>(48)
  external ffi.Array<ffi.Uint8> metal_formula;

  @ffi.Array<ffi.Uint8>(48)
  external ffi.Array<ffi.Uint8> first_formula;

  @ffi.Array<ffi.Uint8>(48)
  external ffi.Array<ffi.Uint8> second_formula;

  @ffi.Double()
  external double x;

  @ffi.Double()
  external double y;
}

final class MoleculePhysicsResult extends ffi.Struct {
  @ffi.Int32()
  external int status;

  @ffi.Int32()
  external int particle_count;

  @ffi.Int32()
  external int event_count;

  external ffi.Pointer<MoleculePhysicsParticle> particles;

  external ffi.Pointer<MoleculePhysicsEvent> events;
}

@ffi.Native<
  ffi.Pointer<MoleculePhysicsResult> Function(
    ffi.Pointer<MoleculePhysicsParticle>,
    ffi.Int32,
    ffi.Double,
    ffi.Double,
    ffi.Double,
    ffi.Double,
    ffi.Int32,
    ffi.Uint64,
  )
>()
external ffi.Pointer<MoleculePhysicsResult> molecule_physics_step(
  ffi.Pointer<MoleculePhysicsParticle> particles,
  int particleCount,
  double width,
  double height,
  double deltaSeconds,
  double temperature,
  int burnerLit,
  int randomSeed,
);

@ffi.Native<ffi.Void Function(ffi.Pointer<MoleculePhysicsResult>)>()
external void molecule_physics_result_free(
  ffi.Pointer<MoleculePhysicsResult> result,
);
