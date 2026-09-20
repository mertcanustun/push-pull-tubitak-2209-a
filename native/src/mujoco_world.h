#ifndef MUJOCO_WORLD_H
#define MUJOCO_WORLD_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <mujoco/mujoco.h>

#include <unordered_map>
#include <vector>

namespace godot {

// MuJoCo'yu Godot'ya baglayan ince katman.
//
// Eksen donusumu burada yapilir:
//   MuJoCo  (x, y, z)  ->  Godot  (x, z, -y)
//   Godot   (x, y, z)  ->  MuJoCo (x, -z, y)
// MuJoCo Z-yukari, Godot Y-yukari oldugu icin.
class MuJoCoWorld : public RefCounted {
	GDCLASS(MuJoCoWorld, RefCounted)

protected:
	static void _bind_methods();

public:
	MuJoCoWorld();
	~MuJoCoWorld();

	bool load_model_from_path(const String &p_path);
	void reset();
	void step(double p_dt);

	void set_body_external_force(const String &p_body, const Vector3 &p_force);
	Vector3 get_body_position(const String &p_body) const;
	Vector3 get_body_velocity(const String &p_body) const;
	void set_body_position(const String &p_body, const Vector3 &p_pos);
	void set_body_velocity(const String &p_body, const Vector3 &p_vel);
	Vector3 get_body_contact_force(const String &p_body) const;
	void set_body_contacts_enabled(const String &p_body, bool p_enabled);

	String get_last_error() const;

private:
	mjModel *m = nullptr;
	mjData *d = nullptr;
	String last_error;
	double accumulator = 0.0;

	// Govde adi -> MuJoCo body id (her cagrida mj_name2id yapmamak icin).
	std::unordered_map<std::string, int> body_ids;
	// Carpisma acilip kapanirken geri yuklemek uzere orijinal degerler.
	std::vector<int> orig_contype;
	std::vector<int> orig_conaffinity;

	int body_id(const String &p_body) const;
	// Serbest eklem (freejoint) adresleri.
	bool free_joint_addr(int p_body, int *r_qposadr, int *r_qveladr) const;

	static inline Vector3 to_godot(const mjtNum *v) {
		return Vector3((float)v[0], (float)v[2], (float)-v[1]);
	}
	static inline void to_mujoco(const Vector3 &v, mjtNum *out) {
		out[0] = (mjtNum)v.x;
		out[1] = (mjtNum)-v.z;
		out[2] = (mjtNum)v.y;
	}
};

} // namespace godot

#endif // MUJOCO_WORLD_H
