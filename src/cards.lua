-- src/cards.lua
--
-- Original card pool for the unofficial fan expansion "Battle of Talingchan 5G".
-- These cards are 100% original content (names, flavor text, stats, ability
-- design) written for this project. Only the underlying *game rules* of
-- Battle of Talingchan are referenced here (turn structure, zones, gem-cost
-- summoning, combat, win condition) - rules are not copyrightable.
-- We deliberately do NOT reproduce any of the official game's card names,
-- artwork, or card text.
--
-- Theme: a "5G internet & modern Thai meme culture" themed expansion -
-- call-center scammers, AI bots, influencers, signal towers, internet
-- deities, etc.

local C = require("src.constants")

local Cards = {}

-- ability schema (interpreted by src/engine/match.lua):
--   { kind = "draw", n = 1 }
--   { kind = "buff_tribe", tribe = "...", power = 1, scope = "ally" }
--   { kind = "direct_attack" }                                 -- avatar static flag
--   { kind = "mob", tribe = "...", power = 1 }                 -- +power per other ally of tribe
--   { kind = "ascension" }                                     -- activated: graveyard -> deck
--   { kind = "earth_absorption" }                               -- counter magic reactive
--   { kind = "weapon_buff", power = 2 }                         -- weapon magic
--   { kind = "land_buff", tribe = "...", power = 1 }            -- land magic, both players
--   { kind = "destroy_avatar", maxPower = 3 }                   -- normal magic
--   { kind = "disruption_discard", n = 1 }
--   { kind = "construct_cost_reduction", tribe = "...", amount = 1 }
--   { kind = "construct_extra_draw", n = 1 }

local list = {

	-- ===================== AVATARS (tribe: human/robot/deity/ghost/alien/scammer) =====================
	{ id = "5G-001", type = C.CardType.AVATAR, name = "ป้าทุย เสาสัญญาณเดินได้",
		cost = 1, gem = 1, power = 2, tribe = "มนุษย์", rarity = "C",
		text = "ป้าทุยยืนถือมือถือเดินทั่วหมู่บ้านเพื่อหาสัญญาณ 5G ที่ดีที่สุด" },

	{ id = "5G-002", type = C.CardType.AVATAR, name = "ลุงหมู แก๊งคอลเซ็นเตอร์",
		cost = 1, gem = 1, power = 1, tribe = "มิจฉาชีพ", rarity = "C",
		text = "เมื่ออัญเชิญใบนี้: จั่วการ์ด 1 ใบ",
		ability = { kind = "draw", n = 1, trigger = "on_play" } },

	{ id = "5G-003", type = C.CardType.AVATAR, name = "บอสใหญ่ มิจฉาชีพข้ามชาติ",
		cost = 5, gem = 2, power = 6, tribe = "มิจฉาชีพ", rarity = "UR", onlyOne = true,
		text = "Avatar เผ่ามิจฉาชีพ ของฝ่ายเดียวกัน ได้รับพลัง +1",
		ability = { kind = "buff_tribe", tribe = "มิจฉาชีพ", power = 1, scope = "ally" } },

	{ id = "5G-004", type = C.CardType.AVATAR, name = "น้องไลน์ บอทตอบแชท",
		cost = 2, gem = 1, power = 2, tribe = "หุ่นยนต์", rarity = "R",
		text = "เมื่ออัญเชิญใบนี้: คู่ต่อสู้ทิ้งการ์ดในมือแบบสุ่ม 1 ใบ",
		ability = { kind = "disruption_discard", n = 1, trigger = "on_play" } },

	{ id = "5G-005", type = C.CardType.AVATAR, name = "AI เทวดาจำแลง",
		cost = 3, gem = 1, power = 4, tribe = "หุ่นยนต์", rarity = "SR",
		text = "[เตะไข่] โจมตี Life Card ของคู่ต่อสู้ได้โดยตรง แม้มี Avatar ฝั่งตรงข้ามอยู่",
		ability = { kind = "direct_attack" } },

	{ id = "5G-006", type = C.CardType.AVATAR, name = "เทวดาเน็ตหลุด",
		cost = 4, gem = 2, power = 3, tribe = "เทวดา", rarity = "SR",
		text = "Avatar เผ่าเทวดา ของฝ่ายเดียวกัน ได้รับพลัง +1",
		ability = { kind = "buff_tribe", tribe = "เทวดา", power = 1, scope = "ally" } },

	{ id = "5G-007", type = C.CardType.AVATAR, name = "ร่างทรงอินฟลูเอนเซอร์",
		cost = 2, gem = 1, power = 2, tribe = "ผี", rarity = "R",
		text = "[จุติ] (Activated, จ่าย 1 เจม): นำการ์ด 1 ใบจากนรกกลับเข้ากองจั่ว แล้วสับกอง",
		ability = { kind = "ascension", activationCost = 1 } },

	{ id = "5G-008", type = C.CardType.AVATAR, name = "ผีบอทรีวิว",
		cost = 1, gem = 1, power = 1, tribe = "ผี", rarity = "C" },

	{ id = "5G-009", type = C.CardType.AVATAR, name = "เอเลี่ยนเสาสัญญาณ",
		cost = 3, gem = 2, power = 2, tribe = "เอเลี่ยน", rarity = "R",
		text = "[หมาหมู่] พลังโจมตี +1 ต่อ Avatar เผ่าเอเลี่ยนตัวอื่นที่อยู่ในสนามฝั่งเดียวกัน",
		ability = { kind = "mob", tribe = "เอเลี่ยน", power = 1 } },

	{ id = "5G-010", type = C.CardType.AVATAR, name = "จ่าหมิว ตำรวจไซเบอร์",
		cost = 2, gem = 1, power = 3, tribe = "มนุษย์", rarity = "C" },

	{ id = "5G-011", type = C.CardType.AVATAR, name = "ยายมัลแวร์",
		cost = 1, gem = 1, power = 1, tribe = "หุ่นยนต์", rarity = "R",
		text = "เมื่ออัญเชิญใบนี้: คู่ต่อสู้ทิ้งการ์ดในมือแบบสุ่ม 1 ใบ",
		ability = { kind = "disruption_discard", n = 1, trigger = "on_play" } },

	{ id = "5G-012", type = C.CardType.AVATAR, name = "ทศกัณฐ์ขายตรง",
		cost = 6, gem = 3, power = 7, tribe = "เทวดา", rarity = "UR", onlyOne = true,
		text = "ราชันย์ธุรกิจขายตรงสิบหน้า สิบมือ สิบสายโทรศัพท์ Avatar เผ่าเทวดา ของฝ่ายเดียวกัน ได้รับพลัง +2",
		ability = { kind = "buff_tribe", tribe = "เทวดา", power = 2, scope = "ally" } },

	{ id = "5G-013", type = C.CardType.AVATAR, name = "หนุมานไรเดอร์",
		cost = 3, gem = 1, power = 4, tribe = "เทวดา", rarity = "R" },

	{ id = "5G-014", type = C.CardType.AVATAR, name = "น้องมายด์ สตรีมเมอร์",
		cost = 2, gem = 1, power = 1, tribe = "มนุษย์", rarity = "C",
		text = "เมื่ออัญเชิญใบนี้: จั่วการ์ด 1 ใบ",
		ability = { kind = "draw", n = 1, trigger = "on_play" } },

	{ id = "5G-015", type = C.CardType.AVATAR, name = "ปีศาจโฆษณาแทรก",
		cost = 2, gem = 1, power = 2, tribe = "ผี", rarity = "R",
		text = "เมื่ออัญเชิญใบนี้: คู่ต่อสู้ทิ้งการ์ดในมือแบบสุ่ม 1 ใบ",
		ability = { kind = "disruption_discard", n = 1, trigger = "on_play" } },

	{ id = "5G-016", type = C.CardType.AVATAR, name = "ร็อบ AI ผู้คุมกฎ",
		cost = 4, gem = 2, power = 4, tribe = "หุ่นยนต์", rarity = "SR",
		text = "Avatar เผ่าหุ่นยนต์ ของฝ่ายเดียวกัน ได้รับพลัง +1",
		ability = { kind = "buff_tribe", tribe = "หุ่นยนต์", power = 1, scope = "ally" } },

	{ id = "5G-017", type = C.CardType.AVATAR, name = "ยักษ์ Wi-Fi",
		cost = 5, gem = 2, power = 5, tribe = "เทวดา", rarity = "SR",
		text = "[เตะไข่] โจมตี Life Card ของคู่ต่อสู้ได้โดยตรง แม้มี Avatar ฝั่งตรงข้ามอยู่",
		ability = { kind = "direct_attack" } },

	{ id = "5G-018", type = C.CardType.AVATAR, name = "เด็กเลี้ยงไก่ติ๊กต็อก",
		cost = 1, gem = 1, power = 1, tribe = "มนุษย์", rarity = "C" },

	{ id = "5G-019", type = C.CardType.AVATAR, name = "แม่ค้าไลฟ์สด",
		cost = 2, gem = 1, power = 2, tribe = "มนุษย์", rarity = "C",
		text = "เมื่ออัญเชิญใบนี้: จั่วการ์ด 1 ใบ",
		ability = { kind = "draw", n = 1, trigger = "on_play" } },

	{ id = "5G-020", type = C.CardType.AVATAR, name = "เอเลี่ยนทูตการตลาด",
		cost = 2, gem = 1, power = 2, tribe = "เอเลี่ยน", rarity = "C",
		text = "[หมาหมู่] พลังโจมตี +1 ต่อ Avatar เผ่าเอเลี่ยนตัวอื่นที่อยู่ในสนามฝั่งเดียวกัน",
		ability = { kind = "mob", tribe = "เอเลี่ยน", power = 1 } },

	-- ===================== MAGIC: NORMAL =====================
	{ id = "5G-101", type = C.CardType.MAGIC, magicType = C.MagicType.NORMAL, name = "แชร์ลูกโซ่",
		cost = 2, gem = 1, rarity = "R",
		text = "ทำลาย Avatar 1 ใบของคู่ต่อสู้ที่มีพลังโจมตี 3 หรือน้อยกว่า",
		ability = { kind = "destroy_avatar", maxPower = 3 } },

	{ id = "5G-102", type = C.CardType.MAGIC, magicType = C.MagicType.NORMAL, name = "บล็อกเบอร์",
		cost = 1, gem = 1, rarity = "C",
		text = "ทำลาย Avatar 1 ใบของคู่ต่อสู้ที่มีพลังโจมตี 1",
		ability = { kind = "destroy_avatar", maxPower = 1 } },

	{ id = "5G-103", type = C.CardType.MAGIC, magicType = C.MagicType.NORMAL, name = "ขอ OTP หน่อยครับ",
		cost = 1, gem = 1, rarity = "SR",
		text = "คู่ต่อสู้ทิ้งการ์ดในมือแบบสุ่ม 2 ใบ",
		ability = { kind = "disruption_discard", n = 2 } },

	{ id = "5G-104", type = C.CardType.MAGIC, magicType = C.MagicType.NORMAL, name = "รีสตาร์ทเราเตอร์",
		cost = 1, gem = 1, rarity = "C",
		text = "จั่วการ์ด 2 ใบ",
		ability = { kind = "draw", n = 2 } },

	-- ===================== MAGIC: WEAPON / MODIFICATION =====================
	{ id = "5G-111", type = C.CardType.MAGIC, magicType = C.MagicType.WEAPON, name = "สายชาร์จไฟแรงสูง",
		cost = 1, gem = 1, rarity = "C",
		text = "สวมใส่ Avatar 1 ใบของคุณ: Avatar นั้นได้รับพลัง +2",
		ability = { kind = "weapon_buff", power = 2 } },

	{ id = "5G-112", type = C.CardType.MAGIC, magicType = C.MagicType.WEAPON, name = "เสาอากาศพกพา",
		cost = 2, gem = 1, rarity = "R",
		text = "สวมใส่ Avatar 1 ใบของคุณ: Avatar นั้นได้รับพลัง +3",
		ability = { kind = "weapon_buff", power = 3 } },

	-- ===================== MAGIC: LAND =====================
	{ id = "5G-121", type = C.CardType.MAGIC, magicType = C.MagicType.LAND, name = "สนามแข่งไลฟ์สด",
		cost = 2, gem = 1, rarity = "R",
		text = "ตราบเท่าที่การ์ดนี้อยู่ในสนาม: Avatar เผ่ามนุษย์ของทั้งสองฝ่าย ได้รับพลัง +1",
		ability = { kind = "land_buff", tribe = "มนุษย์", power = 1 } },

	-- ===================== MAGIC: COUNTER / REACT =====================
	{ id = "5G-131", type = C.CardType.MAGIC, magicType = C.MagicType.COUNTER, name = "ดีดกลับ! เน็ตล่ม",
		cost = 1, gem = 1, rarity = "SR",
		text = "[ธรณีสูบ] เมื่อคู่ต่อสู้อัญเชิญ Avatar ในเทิร์นนี้ ใช้การ์ดนี้เพื่อทำลาย Avatar ใบนั้นทันที",
		ability = { kind = "earth_absorption" } },

	-- ===================== CONSTRUCT =====================
	{ id = "5G-141", type = C.CardType.CONSTRUCT, name = "เสาสัญญาณ 5G",
		cost = 2, gem = 1, rarity = "R",
		text = "ตราบเท่าที่การ์ดนี้อยู่ในสนาม: ค่าคอร์สของ Avatar เผ่าหุ่นยนต์ของคุณลดลง 1 (อย่างน้อย 0)",
		ability = { kind = "construct_cost_reduction", tribe = "หุ่นยนต์", amount = 1 } },

	{ id = "5G-142", type = C.CardType.CONSTRUCT, name = "ออฟฟิศแก๊งคอลเซ็นเตอร์",
		cost = 3, gem = 1, rarity = "SR", onlyOne = true,
		text = "ตราบเท่าที่การ์ดนี้อยู่ในสนาม: ในเฟส Draw ของคุณ จั่วการ์ดเพิ่มอีก 1 ใบ",
		ability = { kind = "construct_extra_draw", n = 1 } },
}

Cards.byId = {}
for _, c in ipairs(list) do
	Cards.byId[c.id] = c
end
Cards.list = list

return Cards
