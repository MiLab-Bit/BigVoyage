extends RefCounted
class_name PoseidonHash
## LEGACY soft_v1 — 仅兼容读旧收据。新 commit 必须走 poseidon8_snarkvm_v1
## （Sidecar `leo run` / FieldMapper）。禁止写入新链上承诺。

const MOD := 2305843009213693951  # 2^61-1
const T := 8
const RF := 4
const RP := 4

static func commit_battle(payload: Dictionary) -> String:
	var limbs: Array = [
		_field_from_hex(str(payload.get("ruleset_h", "0"))),
		_field_from_hex(str(payload.get("fleets_h", "0"))),
		_field_from_hex(str(payload.get("env_h", "0"))),
		posmod(int(payload.get("seed", 0)), MOD),
		posmod(int(payload.get("winner", 0)), MOD),
		posmod(int(payload.get("rounds", 0)), MOD),
		_field_from_hex(str(payload.get("log_root", "0"))),
		_field_from_hex(str(payload.get("season", "1"))),
	]
	var h := poseidon8(limbs)
	return "%016x" % h

static func poseidon8(inputs: Array) -> int:
	var state: Array = []
	for i in T:
		state.append(0)
	for i in mini(inputs.size(), T):
		state[i] = posmod(int(inputs[i]), MOD)
	var rc_i := 0
	for _r in RF:
		for i in T:
			state[i] = posmod(int(state[i]) + _rc(rc_i), MOD)
			rc_i += 1
			state[i] = _sbox(int(state[i]))
		state = _mds(state)
	for _r2 in RP:
		for i in T:
			state[i] = posmod(int(state[i]) + _rc(rc_i), MOD)
			rc_i += 1
		state[0] = _sbox(int(state[0]))
		state = _mds(state)
	for _r3 in RF:
		for i in T:
			state[i] = posmod(int(state[i]) + _rc(rc_i), MOD)
			rc_i += 1
			state[i] = _sbox(int(state[i]))
		state = _mds(state)
	return posmod(int(state[0]), MOD)

static func _sbox(x: int) -> int:
	var x2 := _mul(x, x)
	var x4 := _mul(x2, x2)
	return _mul(x4, x)

static func _mul(a: int, b: int) -> int:
	var aa := posmod(a, MOD)
	var bb := posmod(b, MOD)
	var res := 0
	var x := aa
	var y := bb
	while y > 0:
		if (y & 1) == 1:
			res = posmod(res + x, MOD)
		x = posmod(x + x, MOD)
		y >>= 1
	return res

static func _mds(state: Array) -> Array:
	var out: Array = []
	for i in T:
		var acc := 0
		for j in T:
			acc = posmod(acc + _mul(int(state[j]), _mds_const(i, j)), MOD)
		out.append(acc)
	return out

static func _mds_const(i: int, j: int) -> int:
	return _mod_inverse(i + j + 1)

static func _mod_inverse(a: int) -> int:
	var t := 0
	var newt := 1
	var r := MOD
	var newr := posmod(a, MOD)
	while newr != 0:
		var q := int(r / newr)
		var tmp := newt
		newt = t - q * newt
		t = tmp
		tmp = newr
		newr = r - q * newr
		r = tmp
	if r > 1:
		return 1
	if t < 0:
		t += MOD
	return posmod(t, MOD)

static func _rc(i: int) -> int:
	# 仅用 ≤63bit 字面量（与 Python poseidon_bv._rc 对齐需同步改）
	var x: int = 0x7f4a7c159e3779b9  # 拆位混合
	x = x ^ (i * 0x1b3)
	x = (x ^ (x >> 30)) * 0x1ce4e5b9
	x = (x ^ (x >> 27)) * 0x133111eb
	x = x ^ (x >> 31)
	return posmod(x, MOD)

static func _field_from_hex(s: String) -> int:
	var h := s
	if h.begins_with("0x") or h.begins_with("0X"):
		h = h.substr(2)
	if h.is_empty():
		return 0
	if h.length() > 16:
		h = h.substr(h.length() - 16, 16)
	var v := 0
	for i in h.length():
		var c := h.unicode_at(i)
		var n := 0
		if c >= 48 and c <= 57:
			n = c - 48
		elif c >= 97 and c <= 102:
			n = c - 87
		elif c >= 65 and c <= 70:
			n = c - 55
		v = posmod(v * 16 + n, MOD)
	return v
