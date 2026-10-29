# Native molecule tile physics

This package builds the beaker particle simulation as a C++ native asset and
exposes it to Flutter through Dart FFI. The simulation runs locally; Supabase
continues to handle cloud data and is not called from the per-frame physics loop.
