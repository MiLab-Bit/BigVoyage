extends RefCounted
class_name FieldMapper
## design hex → Aleo field（与 chain/sidecar/field_mapper.py 同规则）
## BN254 Fr modulus；GDScript 用十进制字符串模运算

const FIELD_MOD := "21888242871839275222246405745257275088548364400416034343698204186575808495617"

static func hex_to_field_dec(hex_str: String) -> String:
	var h := hex_str.strip_edges()
	if h.begins_with("0x") or h.begins_with("0X"):
		h = h.substr(2)
	if h.is_empty():
		h = "0"
	if h.length() > 64:
		h = h.substr(h.length() - 64, 64)
	while h.length() < 64:
		h = "0" + h
	var n := _hex_to_dec(h)
	return _mod(n, FIELD_MOD)

static func int_to_field_dec(v: int) -> String:
	return _mod(str(maxi(v, 0)), FIELD_MOD)

static func leo_field(dec: String) -> String:
	return "%sfield" % dec

static func map_commit_payload(payload: Dictionary) -> Dictionary:
	var ruleset := str(payload.get("ruleset_h", payload.get("ruleset_hash", "0")))
	var fleets := str(payload.get("fleets_h", payload.get("hash", "0")))
	var env := str(payload.get("env_h", "0"))
	var log_root := str(payload.get("log_root", payload.get("hash", "0")))
	return {
		"ruleset_h": leo_field(hex_to_field_dec(ruleset)),
		"fleets_h": leo_field(hex_to_field_dec(fleets)),
		"env_h": leo_field(hex_to_field_dec(env)),
		"seed": "%du64" % int(payload.get("seed", 0)),
		"winner": "%du8" % int(payload.get("winner", 0)),
		"rounds": "%du8" % int(payload.get("rounds", 0)),
		"log_root": leo_field(hex_to_field_dec(log_root)),
		"season": "%du32" % int(payload.get("season", 1)),
		"hash_alg": "poseidon8_snarkvm_v1",
	}

static func _hex_to_dec(h: String) -> String:
	var acc := "0"
	for i in h.length():
		var c := h.unicode_at(i)
		var n := 0
		if c >= 48 and c <= 57:
			n = c - 48
		elif c >= 97 and c <= 102:
			n = c - 87
		elif c >= 65 and c <= 70:
			n = c - 55
		acc = _add(_mul(acc, "16"), str(n))
	return acc

static func _mod(a: String, m: String) -> String:
	# a % m for non-negative decimal strings
	if _cmp(a, m) < 0:
		return _strip(a)
	# repeated subtract via long division
	var rem := "0"
	for i in a.length():
		rem = _add(_mul(rem, "10"), a.substr(i, 1))
		while _cmp(rem, m) >= 0:
			rem = _sub(rem, m)
	return _strip(rem)

static func _mul(a: String, b: String) -> String:
	var aa := _strip(a)
	var bb := _strip(b)
	if aa == "0" or bb == "0":
		return "0"
	var bi := int(bb) if bb.length() <= 9 else -1
	if bi >= 0 and bi <= 16:
		var carry := 0
		var out := ""
		var i := aa.length() - 1
		while i >= 0:
			var d := int(aa.substr(i, 1)) * bi + carry
			out = str(d % 10) + out
			carry = int(d / 10)
			i -= 1
		if carry > 0:
			out = str(carry) + out
		return _strip(out)
	# general
	var result := "0"
	var shift := ""
	var j := bb.length() - 1
	while j >= 0:
		var digit := int(bb.substr(j, 1))
		var part := _mul(aa, str(digit)) + shift
		result = _add(result, part)
		shift += "0"
		j -= 1
	return _strip(result)

static func _add(a: String, b: String) -> String:
	var i := _strip(a).length() - 1
	var j := _strip(b).length() - 1
	var carry := 0
	var out := ""
	var aa := _strip(a)
	var bb := _strip(b)
	while i >= 0 or j >= 0 or carry > 0:
		var da := int(aa.substr(i, 1)) if i >= 0 else 0
		var db := int(bb.substr(j, 1)) if j >= 0 else 0
		var s := da + db + carry
		out = str(s % 10) + out
		carry = int(s / 10)
		i -= 1
		j -= 1
	return _strip(out)

static func _sub(a: String, b: String) -> String:
	# assume a >= b
	var aa := _strip(a)
	var bb := _strip(b)
	var i := aa.length() - 1
	var j := bb.length() - 1
	var borrow := 0
	var out := ""
	while i >= 0:
		var da := int(aa.substr(i, 1)) - borrow
		var db := int(bb.substr(j, 1)) if j >= 0 else 0
		if da < db:
			da += 10
			borrow = 1
		else:
			borrow = 0
		out = str(da - db) + out
		i -= 1
		j -= 1
	return _strip(out)

static func _cmp(a: String, b: String) -> int:
	var aa := _strip(a)
	var bb := _strip(b)
	if aa.length() != bb.length():
		return -1 if aa.length() < bb.length() else 1
	if aa == bb:
		return 0
	return -1 if aa < bb else 1

static func _strip(s: String) -> String:
	var t := s.lstrip("0")
	return "0" if t == "" else t
