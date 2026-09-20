#include "mujoco_world.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>
#include <string>

using namespace godot;

void MuJoCoWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_model_from_path", "path"), &MuJoCoWorld::load_model_from_path);
	ClassDB::bind_method(D_METHOD("reset"), &MuJoCoWorld::reset);
	ClassDB::bind_method(D_METHOD("step", "dt"), &MuJoCoWorld::step);
	ClassDB::bind_method(D_METHOD("set_body_external_force", "body", "force"), &MuJoCoWorld::set_body_external_force);
	ClassDB::bind_method(D_METHOD("get_body_position", "body"), &MuJoCoWorld::get_body_position);
	ClassDB::bind_method(D_METHOD("get_body_velocity", "body"), &MuJoCoWorld::get_body_velocity);
	ClassDB::bind_method(D_METHOD("set_body_position", "body", "pos"), &MuJoCoWorld::set_body_position);
	ClassDB::bind_method(D_METHOD("set_body_velocity", "body", "vel"), &MuJoCoWorld::set_body_velocity);
	ClassDB::bind_method(D_METHOD("get_body_contact_force", "body"), &MuJoCoWorld::get_body_contact_force);
	ClassDB::bind_method(D_METHOD("set_body_contacts_enabled", "body", "enabled"), &MuJoCoWorld::set_body_contacts_enabled);
	ClassDB::bind_method(D_METHOD("get_last_error"), &MuJoCoWorld::get_last_error);
}

MuJoCoWorld::MuJoCoWorld() {}

MuJoCoWorld::~MuJoCoWorld() {
	if (d) { mj_deleteData(d); d = nullptr; }
	if (m) { mj_deleteModel(m); m = nullptr; }
}

bool MuJoCoWorld::load_model_from_path(const String &p_path) {
	char error[1024] = "";
	// MuJoCo mutlak bir dosya yolu ister; GDScript tarafi user:// altina
	// kopyalayip globalize_path() ile buraya verir.
	m = mj_loadXML(p_path.utf8().get_data(), nullptr, error, sizeof(error));
	if (!m) {
		last_error = String("mj_loadXML: ") + String(error);
		return false;
	}
	d = mj_makeData(m);
	if (!d) {
		last_error = "mj_makeData basarisiz";
		mj_deleteModel(m);
		m = nullptr;
		return false;
	}

	orig_contype.assign(m->geom_contype, m->geom_contype + m->ngeom);
	orig_conaffinity.assign(m->geom_conaffinity, m->geom_conaffinity + m->ngeom);

	body_ids.clear();
	for (int i = 0; i < m->nbody; i++) {
		const char *name = mj_id2name(m, mjOBJ_BODY, i);
		if (name) {
			body_ids[std::string(name)] = i;
		}
	}

	mj_forward(m, d);
	last_error = "";
	return true;
}

int MuJoCoWorld::body_id(const String &p_body) const {
	auto it = body_ids.find(std::string(p_body.utf8().get_data()));
	return it == body_ids.end() ? -1 : it->second;
}

bool MuJoCoWorld::free_joint_addr(int p_body, int *r_qposadr, int *r_qveladr) const {
	if (!m || p_body < 0) return false;
	int jnt = m->body_jntadr[p_body];
	if (jnt < 0 || m->jnt_type[jnt] != mjJNT_FREE) return false;
	*r_qposadr = m->jnt_qposadr[jnt];
	*r_qveladr = m->jnt_dofadr[jnt];
	return true;
}

void MuJoCoWorld::reset() {
	if (!m || !d) return;
	mj_resetData(m, d);
	accumulator = 0.0;
	mj_forward(m, d);
}

void MuJoCoWorld::step(double p_dt) {
	if (!m || !d) return;
	// Godot karesi ile MuJoCo adimi ayni degil; farki biriktirip
	// tam sayida mj_step atiyoruz (sabit adim = kararli fizik).
	accumulator += p_dt;
	int guard = 0;
	while (accumulator >= m->opt.timestep && guard < 20000) {
		mj_step(m, d);
		accumulator -= m->opt.timestep;
		guard++;
	}
}

void MuJoCoWorld::set_body_external_force(const String &p_body, const Vector3 &p_force) {
	int b = body_id(p_body);
	if (!d || b < 0) return;
	mjtNum f[3];
	to_mujoco(p_force, f);
	// xfrc_applied: [fx fy fz tx ty tz] - kutle merkezine uygulanan dis kuvvet.
	// Yercekimi ve akiskan surukleme motor tarafindan AYRICA eklenir,
	// yani bu kuvvet de onlarla birlikte cozulur.
	d->xfrc_applied[6 * b + 0] = f[0];
	d->xfrc_applied[6 * b + 1] = f[1];
	d->xfrc_applied[6 * b + 2] = f[2];
}

Vector3 MuJoCoWorld::get_body_position(const String &p_body) const {
	int b = body_id(p_body);
	if (!d || b < 0) return Vector3();
	return to_godot(&d->xpos[3 * b]);
}

Vector3 MuJoCoWorld::get_body_velocity(const String &p_body) const {
	int b = body_id(p_body);
	int qp, qv;
	if (!d || !free_joint_addr(b, &qp, &qv)) return Vector3();
	// Serbest eklemde ilk 3 dof dunya eksenlerinde dogrusal hizdir.
	return to_godot(&d->qvel[qv]);
}

void MuJoCoWorld::set_body_position(const String &p_body, const Vector3 &p_pos) {
	int b = body_id(p_body);
	int qp, qv;
	if (!d || !free_joint_addr(b, &qp, &qv)) return;
	mjtNum p[3];
	to_mujoco(p_pos, p);
	d->qpos[qp + 0] = p[0];
	d->qpos[qp + 1] = p[1];
	d->qpos[qp + 2] = p[2];
	mj_forward(m, d);
}

void MuJoCoWorld::set_body_velocity(const String &p_body, const Vector3 &p_vel) {
	int b = body_id(p_body);
	int qp, qv;
	if (!d || !free_joint_addr(b, &qp, &qv)) return;
	mjtNum v[3];
	to_mujoco(p_vel, v);
	d->qvel[qv + 0] = v[0];
	d->qvel[qv + 1] = v[1];
	d->qvel[qv + 2] = v[2];
}

Vector3 MuJoCoWorld::get_body_contact_force(const String &p_body) const {
	int b = body_id(p_body);
	if (!m || !d || b < 0) return Vector3();

	mjtNum total[3] = { 0, 0, 0 };
	for (int i = 0; i < d->ncon; i++) {
		const mjContact *con = d->contact + i;
		int b1 = m->geom_bodyid[con->geom1];
		int b2 = m->geom_bodyid[con->geom2];
		if (b1 != b && b2 != b) continue;

		mjtNum f[6];
		mj_contactForce(m, d, i, f); // temas cercevesinde: [normal, t1, t2, tork...]

		// Temas cercevesinden dunya eksenlerine: con->frame satirlari eksenlerdir.
		mjtNum w[3] = { 0, 0, 0 };
		for (int a = 0; a < 3; a++) {
			for (int k = 0; k < 3; k++) {
				w[k] += con->frame[3 * a + k] * f[a];
			}
		}
		// mj_contactForce ikinci cisme (geom2) etki eden kuvveti verir.
		double sign = (b2 == b) ? 1.0 : -1.0;
		for (int k = 0; k < 3; k++) total[k] += sign * w[k];
	}
	return to_godot(total);
}

void MuJoCoWorld::set_body_contacts_enabled(const String &p_body, bool p_enabled) {
	int b = body_id(p_body);
	if (!m || b < 0) return;
	// Govdeye ait tum geometrilerin contype/conaffinity degerlerini degistir.
	// 0 = hicbir seyle carpismaz. Yercekimi ve akiskan surukleme etkilenmez:
	// tam olarak senaryo planinin istedigi durum.
	int start = m->body_geomadr[b];
	int count = m->body_geomnum[b];
	for (int g = start; g < start + count; g++) {
		if (g < 0 || g >= m->ngeom) continue;
		m->geom_contype[g] = p_enabled ? (orig_contype[g] ? orig_contype[g] : 1) : 0;
		m->geom_conaffinity[g] = p_enabled ? (orig_conaffinity[g] ? orig_conaffinity[g] : 1) : 0;
	}
}

String MuJoCoWorld::get_last_error() const {
	return last_error;
}
