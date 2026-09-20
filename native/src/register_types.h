#ifndef MUJOCO_REGISTER_TYPES_H
#define MUJOCO_REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_mujoco_module(ModuleInitializationLevel p_level);
void uninitialize_mujoco_module(ModuleInitializationLevel p_level);

#endif // MUJOCO_REGISTER_TYPES_H
