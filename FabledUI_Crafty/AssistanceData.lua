local M = _G.FabledUI_Crafty
M.AssistanceData = M.AssistanceData or {}
local D = M.AssistanceData
local L = setmetatable({ ['Frozen Herb'] = 'Frozen Herb' }, { __index = function(_, k) return k end })

D.herb = {
	[765] = { -- Silverleaf
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 39151},
		},
		['found'] = {
			['location'] = { 'Elwynn Forest', 'Tirisfal Glades', 'Mulgore', 'Teldrassil', 'Dun Morogh', 'Eversong Woods', 'Azuremyst Isle', 'Bloodmyst Isle', 'Durotar', 'Ghostlands', 'Silverpine Forest', 'Gilneas', 'Loch Modan', 'Gilneas City', 'Westfall', 'The Lost Isles', 'The Wandering Isle', 'Darkshore', 'New Tinkertown', 'Northern Barrens', 'Azshara' },
		},
	};
	[2447] = { -- Peacebloom
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 39151},
		},
		['found'] = {
			['location'] = { 'Durotar', 'Teldrassil', 'Tirisfal Glades', 'Azuremyst Isle', 'Mulgore', 'Dun Morogh', 'Eversong Woods', 'Gilneas', 'Elwynn Forest', 'Bloodmyst Isle', 'The Lost Isles', 'Gilneas City', 'Ghostlands', 'Loch Modan', 'Westfall', 'Azshara', 'The Wandering Isle', 'New Tinkertown', 'Darkshore', 'Silverpine Forest', 'Northern Barrens' },
		},
	};
	[2449] = { -- Earthroot
		['skill'] = 15,
		['items'] = {
			[1] = {['chance'] = '100%', 39151},
		},
		['found'] = {
			['location'] = { 'Durotar', 'Silverpine Forest', 'Tirisfal Glades', 'Elwynn Forest', 'Redridge Mountains', 'Teldrassil', 'Mulgore', 'Dun Morogh', 'Eversong Woods', 'Azuremyst Isle', 'Ghostlands', 'The Lost Isles', 'Bloodmyst Isle', 'The Wandering Isle', 'Westfall', 'Gilneas', 'Gilneas City', 'Loch Modan', 'Azshara', 'Northern Barrens', 'Darkshore' },
		},
	};
	[785] = { -- Mageroyal
		['skill'] = 50,
		['items'] = {
			[1] = {['chance'] = '100%', 39334},
			[2] = {['chance'] = '±25%', 43103},
		},
		['found'] = {
			['location'] = {'Durotar', 'Northern Barrens', 'Silverpine Forest', 'Hillsbrad Foothills', 'Duskwood', 'Loch Modan', 'Redridge Mountains', 'Westfall', 'Wetlands', 'Teldrassil', 'Darkshore', 'Ashenvale', 'Stonetalon Mountains', 'Azshara', 'Ghostlands', 'Bloodmyst Isle'},
			['chance'] = '±20%',
			['node'] = {L['Frozen Herb']},
		},
	};
	[2450] = { -- Briarthorn
		['skill'] = 70,
		['items'] = {
			[1] = {['chance'] = '100%', 39334},
			[2] = {['chance'] = '±25%', 43103},
		},
		['found'] = {
			['location'] = {'Hillsbrad Foothills', 'Darkshore', 'Silverpine Forest', 'Northern Barrens', 'Azshara', 'Loch Modan', 'Redridge Mountains', 'Westfall', 'Bloodmyst Isle', 'Wetlands', 'Stonetalon Mountains', 'Ghostlands', 'Duskwood', 'Teldrassil', 'Ashenvale'},
			['chance'] = '±40%',
			['node'] = {L['Frozen Herb']},
		},
	};
	[2452] = { -- Swiftthistle
		['skill'] = '50|70',
		['items'] = {
			[1] = {['chance'] = '100%', 39334},
			[2] = {['chance'] = '±25%', 43103},
		},
		['found'] = {
			['chance'] = '±35%',
			['node'] = {785, 2450},
		},
	};
	[2453] = { -- Bruiseweed
		['skill'] = 100,
		['items'] = {
			[1] = {['chance'] = '100%', 39334},
			[2] = {['chance'] = '±50%', 43103},
		},
		['found'] = {
			['location'] = {'Northern Stranglethorn', 'Duskwood', 'Redridge Mountains', 'Wetlands', 'Ashenvale', 'Stonetalon Mountains', 'Westfall', 'The Hinterlands', 'Hillsbrad Foothills', 'Arathi Highlands', 'Ghostlands', 'Bloodmyst Isle', 'Loch Modan', 'Northern Barrens'},
			['chance'] = '±40%',
			['node'] = {L['Frozen Herb']},
		},
	};
	[3820] = { -- Stranglekelp
		['skill'] = 85,
		['items'] = {
			[1] = {['chance'] = '100%', 39334},
			[2] = {['chance'] = '±50%', 43103},
		},
		['found'] = {
			['location'] = {'Thousand Needles', 'Westfall', 'Wetlands', 'The Cape of Stranglethorn', 'Western Plaguelands', 'Hillsbrad Foothills', 'Northern Stranglethorn', 'Swamp of Sorrows', 'The Hinterlands', 'Bloodmyst Isle', 'Dustwallow Marsh', 'Silverpine Forest', 'Darkshore', 'Ghostlands', 'Ashenvale', 'Stranglethorn Vale'},
		},
	};
	[3355] = { -- Wild Steelbloom
		['skill'] = 115,
		['items'] = {
			[1] = {['chance'] = '100%', 39338},
			[2] = {['chance'] = '±25%', 43104},
		},
		['found'] = {
			['location'] = {'Arathi Highlands', 'Stonetalon Mountains', 'Northern Stranglethorn', 'Ashenvale', 'Desolace', 'Wetlands', 'Duskwood', 'Stranglethorn Vale', 'The Hinterlands', 'Hillsbrad Foothills', 'Thousand Needles'},
		},
	};
	[3356] = { -- Kingsblood
		['skill'] = 125,
		['items'] = {
			[1] = {['chance'] = '100%', 39338},
			[2] = {['chance'] = '±50%', 43104},
		},
		['found'] = {
			['location'] = {'Northern Stranglethorn', 'Wetlands', 'Western Plaguelands', 'Arathi Highlands', 'Southern Barrens', 'Desolace', 'The Hinterlands', 'Duskwood', 'Dustwallow Marsh', 'Stranglethorn Vale', 'Feralas', 'Northern Barrens', 'Ashenvale', 'Stonetalon Mountains'},
		},
	};
	[3357] = { -- Liferoot
		['skill'] = 150,
		['items'] = {
			[1] = {['chance'] = '100%', 39338},
			[2] = {['chance'] = '±50%', 43104},
		},
		['found'] = {
			['location'] = {'Eastern Plaguelands', 'Western Plaguelands', 'Northern Stranglethorn', 'Dustwallow Marsh', 'Wetlands', 'Arathi Highlands', 'Thousand Needles', 'Stranglethorn Vale', 'The Hinterlands', 'Ashenvale', 'Desolace', 'Southern Barrens', 'Netherstorm', 'The Cape of Stranglethorn'},
		},
	};
	[3369] = { -- Grave Moss
		['skill'] = 120,
		['items'] = {
			[1] = {['chance'] = '100%', 39338},
			[2] = {['chance'] = '±25%', 43104},
		},
		['found'] = {
			['location'] = {'Duskwood', 'Arathi Highlands', 'Wetlands', 'Hillsbrad Foothills'},
		},
	};
	[3818] = { -- Fadeleaf
		['skill'] = 160,
		['items'] = {
			[1] = {['chance'] = '100%', 39339},
			[2] = {['chance'] = '±25%', 43105},
		},
		['found'] = {
			['location'] = {'Feralas', 'The Cape of Stranglethorn', 'Dustwallow Marsh', 'Arathi Highlands', 'Western Plaguelands', 'The Hinterlands', 'Stranglethorn Vale'},
		},
	};
	[3819] = { -- Dragon's Teeth
		['skill'] = 195,
		['items'] = {
			[1] = {['chance'] = '100%', 39339},
			[2] = {['chance'] = '±50%', 43105},
		},
		['found'] = {
			['location'] = {'Badlands'},
		},
	};
	[3821] = { -- Goldthorn
		['skill'] = 170,
		['items'] = {
			[1] = {['chance'] = '100%', 39339},
			[2] = {['chance'] = '±25%', 43105},
		},
		['found'] = {
			['location'] = {'Arathi Highlands', 'The Hinterlands', 'Dustwallow Marsh', 'Stranglethorn Vale', 'Southern Barrens', 'Feralas', 'Desolace', 'The Cape of Stranglethorn'},
		},
	};
	[3358] = { -- Khadgar's Whisker
		['skill'] = 185,
		['items'] = {
			[1] = {['chance'] = '100%', 39339},
			[2] = {['chance'] = '±50%', 43105},
		},
		['found'] = {
			['location'] = {'Eastern Plaguelands', 'Western Plaguelands', 'Feralas', 'The Cape of Stranglethorn', 'Arathi Highlands', 'Dustwallow Marsh', 'The Hinterlands', 'Desolace', 'Southern Barrens', 'Stranglethorn Vale'},
		},
	};
	[8831] = { -- Purple Lotus
		['skill'] = 210,
		['items'] = {
			[1] = {['chance'] = '100%', 39340},
			[2] = {['chance'] = '±25%', 43106},
		},
		['found'] = {
			['location'] = {'Felwood'},
		},
	};
	[8836] = { -- Arthas' Tears
		['skill'] = 220,
		['items'] = {
			[1] = {['chance'] = '100%', 39340},
			[2] = {['chance'] = '±25%', 43106},
		},
		['found'] = {
			['location'] = {'Western Plaguelands', 'Eastern Plaguelands', 'Felwood'},
		},
	};
	[8838] = { -- Sungrass
		['skill'] = 230,
		['items'] = {
			[1] = {['chance'] = '100%', 39340},
			[2] = {['chance'] = '±25%', 43106},
		},
		['found'] = {
			['location'] = {'Eastern Plaguelands', 'Thousand Needles', 'Badlands', 'Burning Steppes', 'Silithus', 'Searing Gorge', 'Tanaris', 'Un\'Goro Crater', 'The Hinterlands', 'Western Plaguelands', 'Blasted Lands', 'Feralas', 'Azshara', 'Felwood'},
		},
	};
}
D.milling = {
	[39151] = { -- Alabaster Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 2449, 2447, 765},
		},
	};
	
	[39334] = { -- Dusky Pigment
		['skill'] = 25,
		['items'] = {
			[1] = {['chance'] = '100%', 2450, 2453, 2452, 785, 3820},
		},
	};
	[43103] = { -- Verdant Pigment
		['skill'] = 25,
		['items'] = {
			[1] = {['chance'] = '±50%', 2453, 3820},
			[2] = {['chance'] = '±25%', 2450, 785, 2452},
		},
	};
	
	[39338] = { -- Golden Pigment
		['skill'] = 75,
		['items'] = {
			[1] = {['chance'] = '100%', 3356, 3355, 3369, 3357},
		},
	};
	[43104] = { -- Burnt Pigment
		['skill'] = 75,
		['items'] = {
			[1] = {['chance'] = '±50%', 3357, 3356},
			[2] = {['chance'] = '±25%', 3369, 3355},
		},
	};
	
	[39339] = { -- Emerald Pigment
		['skill'] = 125,
		['items'] = {
			[1] = {['chance'] = '100%', 3818, 3819, 3821, 3358},
		},
	};
	[43105] = { -- Indigo Pigment
		['skill'] = 125,
		['items'] = {
			[1] = {['chance'] = '±50%', 3819, 3358},
			[2] = {['chance'] = '±25%', 3821, 3818},
		},
	};
	
	[39340] = { -- Violet Pigment
		['skill'] = 175,
		['items'] = {
			[1] = {['chance'] = '100%', 8839, 4625, 8845, 8846, 8831, 8838, 8836},
		},
	};
	[43106] = { -- Ruby Pigment
		['skill'] = 175,
		['items'] = {
			[1] = {['chance'] = '±50%', 8845, 8839, 8846},
			[2] = {['chance'] = '±25%', 4625, 8838, 8836, 8831},
		},
	};
	
	[39341] = { -- Silvery Pigment
		['skill'] = 225,
		['items'] = {
			[1] = {['chance'] = '100%', 13463, 13464, 13467, 13465, 13466},
		},
	};
	[43107] = { -- Sapphire Pigment
		['skill'] = 225,
		['items'] = {
			[1] = {['chance'] = '±50%', 13467, 13466, 13465},
			[2] = {['chance'] = '±25%', 13463, 13464},
		},
	};
	
	-- The Burning Crusade pigments --
	[39342] = { -- Nether Pigment
		['skill'] = 275,
		['items'] = {
			[1] = {['chance'] = '100%', 22785, 22786, 22787, 22789, 22790, 22791, 22792, 22793},
		},
	};
	[43108] = { -- Ebon Pigment
		['skill'] = 275,
		['items'] = {
			[1] = {['chance'] = '±50%', 22792, 22791, 22790, 22793},
			[2] = {['chance'] = '±25%', 22786, 22785, 22787, 22789},
		},
	};
	
	-- Wrath of the Lich King pigments --
	[39343] = { -- Azure Pigment
		['skill'] = 325,
		['items'] = {
			[1] = {['chance'] = '100%', 36901, 36903, 36904, 36905, 36906, 36907, 37921, 39970},
		},
	};
	[43109] = { -- Icy Pigment
		['skill'] = 325,
		['items'] = {
			[1] = {['chance'] = '±50%', 36903, 36905, 36906},
			[2] = {['chance'] = '±25%', 36901, 36904, 36907, 37921, 39970},
		},
	};
	
	-- Cataclysm pigments --
	[61979] = { -- Ashen Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 52983, 52984, 52985, 52986, 52987, 52988},
		},
	};
	[61980] = { -- Burning Embers
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±50%', 52987, 52988},
			[2] = {['chance'] = '±25%', 52983, 52984, 52985, 52986},
		},
	};
	
	-- Mist of Pandaria pigments --
	[79251] = { -- Shadow Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 72234, 72235, 72237, 79010, 79011, 89639},
		},
	};
	[79253] = { -- Misty Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±50%', 79011},
			[2] = {['chance'] = '±25%', 72234, 72235, 72237, 79010, 89639},
		},
	};
	
	-- Warlords of Draenor pigments --
	[114931] = { -- Cerulean Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 109124, 109125, 109126, 109127, 109128, 109129},
		},
	};
	
	-- Legion pigments --
	[129032] = { -- Roseate Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 124101, 124102, 124103, 124104, 124105, 124106, 128304, 151565},
		},
	};
	[129034] = { -- Sallow Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±50%', 124106},
			[2] = {['chance'] = '±20%', 124101, 124102, 124103, 124104, 124105, 151565},
			[3] = {['chance'] = '±1.5%', 128304},
		},
	};
	
	-- Battle for Azeroth pigments --
	[153635] = { -- Ultramarine Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 152505, 152506, 152507, 152508, 152509, 152510, 152511},
		},
	};
	[153636] = { -- Crimson Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±65%', 152505, 152506, 152507, 152508, 152509, 152510, 152511},
		},
	};
	[153669] = { -- Viridescent Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 152510},
			[2] = {['chance'] = '±30%', 152505, 152506, 152507, 152508, 152509, 152511},
		},
	};
	[168662] = { -- Maroon Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 168487},
		},
	};
	
	-- Shadowlands pigments --
	[173056] = { -- Umbral Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±65%', 168583, 168589},
			[2] = {['chance'] = '±50%', 169701, 171315},
			[3] = {['chance'] = '±35%', 168586, 170554},
		},
	};
	[173057] = { -- Luminous Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±65%', 168586, 170554},
			[2] = {['chance'] = '±50%', 169701, 171315},
			[3] = {['chance'] = '±35%', 168583, 168589},
		},
	};
	[175788] = { -- Tranquil Pigment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 171315},
			[2] = {['chance'] = '±5%', 168583, 168589, 169701, 168586, 170554},
		},
	};
	
	-- Dragonflight pigments --
	[198412] = { -- Serene Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191467},
		},
	};
	[198413] = { -- Serene Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191468},
		},
	};
	[198414] = { -- Serene Pigment *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191469},
		},
	};
	[198415] = { -- Flourishing Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191470},
		},
	};
	[198416] = { -- Flourishing Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191471},
		},
	};
	[198417] = { -- Flourishing Pigment *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191472},
		},
	};
	[198418] = { -- Blazing Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191464},
		},
	};
	[198419] = { -- Blazing Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191465},
		},
	};
	[198420] = { -- Blazing Pigment *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191466},
		},
	};
	[198421] = { -- Shimmering Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191460},
		},
	};
	[198422] = { -- Shimmering Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191461},
		},
	};
	[198423] = { -- Shimmering Pigment *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 191462},
		},
	};
	
	-- The War Within pigments --
	[222618] = { -- Nacreous Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210796 },
		},
	},
	[222619] = { -- Nacreous Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210797 },
		},
	},
	[222620] = { -- Nacreous Pigment *3
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210798 },
		},
	},
	[222612] = { -- Luredrop Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210799 },
		},
	},
	[222613] = { -- Luredrop Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210800 },
		},
	},
	[222614] = { -- Luredrop Pigment *3
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210801 },
		},
	},
	[224802] = { -- Orbinid Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210802 },
		},
	},
	[224801] = { -- Orbinid Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210803 },
		},
	},
	[224800] = { -- Orbinid Pigment *3
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210804 },
		},
	},
	[224805] = { -- Blossom Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210805 },
		},
	},
	[224804] = { -- Blossom Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210806 },
		},
	},
	[224803] = { -- Blossom Pigment *3
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 210807 },
		},
	},
	
	-- Midnight pigments --
	[245803] = { -- Argentleaf Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 236776 },
		},
	},
	[245804] = { -- Argentleaf Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 236777 },
		},
	},
	[245807] = { -- Powder Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 236761 },
		},
	},
	[245808] = { -- Powder Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 236767 },
		},
	},
	[245865] = { -- Sanguithorn Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 236770 },
		},
	},
	[245864] = { -- Sanguithorn Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 236771 },
		},
	},
	[245867] = { -- Mana Lily Pigment *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 236778 },
		},
	},
	[245866] = { -- Mana Lily Pigment *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '100%', 236779 },
		},
	},
}
D.ore = {
	[2770] = { -- Copper Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±50%', 774, 818},
			[2] = {['chance'] = '±10%', 1210},
		},
		['found'] = {
			['location'] = {'Durotar', 'Darkshore', 'Elwynn Forest', 'Dun Morogh', 'Northern Barrens', 'Azshara', 'Westfall', 'Tirisfal Glades', 'Gilneas', 'Mulgore', 'Loch Modan', 'Eversong Woods', 'Azuremyst Isle', 'Redridge Mountains', 'The Lost Isles', 'Bloodmyst Isle', 'Gilneas City', 'Ghostlands', 'Silverpine Forest', 'The Wandering Isle', 'Duskwood', 'Stonetalon Mountains', 'Wetlands', 'Thousand Needles', 'Ashenvale', 'New Tinkertown'},
		},
	};
	
	[2771] = { -- Tin Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±40%', 1206, 1210, 1705},
			[2] = {['chance'] = '±5%', 1529, 3864, 7909},
		},
		['found'] = {
			['location'] = {'Hillsbrad Foothills', 'Ashenvale', 'Northern Stranglethorn', 'Stonetalon Mountains', 'Redridge Mountains', 'Duskwood', 'Wetlands', 'Loch Modan', 'Arathi Highlands', 'Bloodmyst Isle', 'Westfall', 'Thousand Needles', 'Silverpine Forest', 'Ghostlands', 'Darkshore', 'The Hinterlands', 'Dustwallow Marsh'},
		},
	};
	
	[2772] = { -- Iron Ore
		['skill'] = 100,
		['items'] = {
			[1] = {['chance'] = '±35%', 1529, 1705, 3864},
			[2] = {['chance'] = '±5%', 7909, 7910},
		},
		['found'] = {
			['location'] = {'Feralas', 'Desolace', 'Arathi Highlands', 'Western Plaguelands', 'Eastern Plaguelands', 'The Cape of Stranglethorn', 'Southern Barrens', 'Thousand Needles', 'The Hinterlands', 'Northern Stranglethorn', 'Dustwallow Marsh', 'Duskwood', 'Wetlands', 'Badlands', 'Stranglethorn Vale', 'Tanaris'},
		},
	};
	
	[2775] = { -- Silver Ore
		['skill'] = 50,
		['found'] = {
			['location'] = {'Feralas', 'Northern Stranglethorn', 'Hillsbrad Foothills', 'Stonetalon Mountains', 'Desolace', 'Arathi Highlands', 'The Cape of Stranglethorn', 'Southern Barrens', 'Duskwood', 'Wetlands', 'Redridge Mountains', 'Thousand Needles', 'The Hinterlands', 'Loch Modan', 'Bloodmyst Isle', 'Silverpine Forest', 'Dustwallow Marsh', 'Darkshore', 'Ghostlands', 'Westfall'},
		},
	};
	
	[2776] = { -- Gold Ore
		['skill'] = 115,
		['found'] = {
			['location'] = {'Thousand Needles', 'Feralas', 'Eastern Plaguelands', 'Burning Steppes', 'Badlands', 'Felwood', 'Searing Gorge', 'Western Plaguelands', 'Desolace', 'The Cape of Stranglethorn', 'Arathi Highlands', 'Southern Barrens', 'Tanaris', 'Northern Stranglethorn', 'The Hinterlands', 'Duskwood', 'Dustwallow Marsh', 'Un\'Goro Crater'},
		},
	};
	
	[3858] = { -- Mithril Ore
		['skill'] = 150,
		['items'] = {
			[1] = {['chance'] = '±35%', 3864, 7909, 7910},
			[2] = {['chance'] = '±5%', 12361, 12364, 12799, 12800},
		},
		['found'] = {
			['location'] = {'Thousand Needles', 'Badlands', 'Searing Gorge', 'Burning Steppes', 'Felwood', 'Tanaris', 'Eastern Plaguelands', 'The Hinterlands', 'Arathi Highlands', 'Dustwallow Marsh', 'Un\'Goro Crater'},
		},
	};
	
	[7911] = { -- Truesilver Ore
		['skill'] = 165,
		['found'] = {
			['location'] = {'Winterspring', 'Thousand Needles', 'Burning Steppes', 'Badlands', 'Felwood', 'Searing Gorge', 'Silithus', 'Blasted Lands', 'Swamp of Sorrows', 'Eastern Plaguelands', 'Tanaris', 'Un\'Goro Crater'},
		},
	};
	
	[10620] = { -- Thorium Ore
		['skill'] = '200|215',
		['items'] = {
			[1] = {['chance'] = '±30%', 12361, 12364, 12799, 12800},
			[2] = {['chance'] = '±15%', 7910},
		},
		['found'] = {
			['location'] = {'Winterspring', 'Silithus', 'Un\'Goro Crater', 'Swamp of Sorrows', 'Blasted Lands', 'Tanaris'},
		},
	};
	
	-- The Burning Crusade ores --
	[23424] = { -- Fel Iron Ore
		['skill'] = 275,
		['items'] = {
			[1] = {['chance'] = '±15%', 21929, 23077, 23079, 23107, 23112, 23117},
			[2] = {['chance'] = '±1.5%', 23436, 23437, 23438, 23439, 23440, 23441},
		},
		['found'] = {
			['location'] = {'Hellfire Peninsula', 'Zangarmarsh', 'Nagrand', 'Shadowmoon Valley', 'Blade\'s Edge Mountains', 'Terokkar Forest', 'Netherstorm'},
		},
	};
	[23425] = { -- Adamantite Ore
		['skill'] = '325|350',
		['items'] = {
			[1] = {['chance'] = '100%', 24243},
			[2] = {['chance'] = '±15%', 21929, 23077, 23079, 23107, 23112, 23117},
			[3] = {['chance'] = '±5%', 23436, 23437, 23438, 23439, 23440, 23441},
		},
		['found'] = {
			['location'] = {'Nagrand', 'Blade\'s Edge Mountains', 'Netherstorm', 'Shadowmoon Valley', 'Terokkar Forest', 'Zangarmarsh', 'Isle of Quel\'Danas'},
		},
	};
	[23426] = { -- Khorium Ore
		['skill'] = 375,
		['found'] = {
			['location'] = {'Nagrand', 'Blade\'s Edge Mountains', 'Netherstorm', 'Shadowmoon Valley', 'Terokkar Forest', 'Isle of Quel\'Danas'},
		},
	};
	[23427] = { -- Eternium Ore
		['skill'] = '275|325|350|375',
		['found'] = {
			['chance'] = '±25%',
			['node'] = {23426, 23425, 23424},
		},
	};
	
	-- Wratch of the Lich King ores --
	[36909] = { -- Cobalt Ore
		['skill'] = '350|375',
		['items'] = {
			[1] = {['chance'] = '±25%', 36917, 36920, 36923, 36926, 36929, 36932},
			[2] = {['chance'] = '±1.5%', 36918, 36921, 36924, 36927, 36930, 36933},
		},
		['found'] = {
			['location'] = {'Zul\'Drak', 'Howling Fjord', 'Borean Tundra', 'Dragonblight', 'Grizzly Hills', 'The Storm Peaks', 'Crystalsong Forest'},
		},
	};
	[36910] = { -- Titanium Ore
		['skill'] = 450,
		['items'] = {
			[1] = {['chance'] = '±50%', 46849},
			[2] = {['chance'] = '±25%', 36917, 36920, 36923, 36926, 36929, 36932},
			[3] = {['chance'] = '±5%', 36918, 36921, 36924, 36927, 36930, 36933, 36919, 36922, 36925, 36928, 36931, 36934},
		},
		['found'] = {
			['location'] = {'Icecrown', 'Sholazar Basin', 'The Storm Peaks', 'Wintergrasp'},
		},
	};
	[36912] = { -- Saronite Ore
		['skill'] = '400|425',
		['items'] = {
			[1] = {['chance'] = '±15%', 36917, 36920, 36923, 36926, 36929, 36932},
			[2] = {['chance'] = '±5%', 36918, 36921, 36924, 36927, 36930, 36933},
		},
		['found'] = {
			['location'] = {'Icecrown', 'Sholazar Basin', 'The Storm Peaks', 'Wintergrasp', 'Zul\'Drak'},
		},
	};
	
	-- Cataclysm ores --
	[52185] = { -- Elementium Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 52177, 52178, 52179, 52180, 52181, 52182},
			[2] = {['chance'] = '±5%', 52190, 52191, 52192, 52193, 52194, 52195},
		},
		['found'] = {
			['location'] = {'Deepholm', 'Twilight Highlands', 'Mount Hyjal', 'Tol Barad Peninsula', 'Tol Barad'},
		},
	};
	[53038] = { -- Obsidium Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 52177, 52178, 52179, 52180, 52181, 52182},
			[2] = {['chance'] = '±5%', 52190, 52191, 52192, 52193, 52194, 52195},
		},
		['found'] = {
			['location'] = {'Deepholm', 'Mount Hyjal', 'Abyssal Depths', 'Shimmering Expanse', 'Kelp\'thar Forest'},
		},
	};
	[52183] = { -- Pyrite Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 52327},
			[2] = {['chance'] = '±15%', 52177, 52178, 52179, 52180, 52181, 52182},
			[3] = {['chance'] = '±5%', 52190, 52191, 52192, 52193, 52194, 52195},
		},
		['found'] = {
			['location'] = {'Twilight Highlands', 'Mount Hyjal'},
		},
	};
	
	-- Mist of Pandaria ores --
	[72092] = { -- Ghost Iron Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±80%', 90407},
			[2] = {['chance'] = '±25%', 76130, 76133, 76134, 76135, 76136, 76137},
			[3] = {['chance'] = '±5%', 76131, 76138, 76139, 76140, 76141, 76142},
		},
		['found'] = {
			['location'] = {'The Jade Forest', 'Valley of the Four Winds', 'Dread Wastes', 'Kun-Lai Summit', 'Townlong Steppes', 'Krasarang Wilds', 'Vale of Eternal Blossoms', 'Timeless Isle', 'The Veiled Stair'},
		},
	};
	[72093] = { -- Kyparite Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 90407},
			[2] = {['chance'] = '±25%', 76130, 76133, 76134, 76135, 76136, 76137},
			[3] = {['chance'] = '±5%', 76131, 76138, 76139, 76140, 76141, 76142},
		},
		['found'] = {
			['location'] = {'Dread Wastes', 'Townlong Steppes'},
		},
	};
	[72094] = { -- Black Trillium Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 90407},
			[2] = {['chance'] = '±15%', 76130, 76133, 76134, 76135, 76136, 76137, 76131, 76138, 76139, 76140, 76141, 76142},
		},
		['found'] = {
			['location'] = {'Dread Wastes', 'Kun-Lai Summit', 'Townlong Steppes', 'Vale of Eternal Blossoms', 'The Jade Forest', 'Valley of the Four Winds', 'Timeless Isle'},
		},
	};
	[72103] = { -- White Trillium Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 90407},
			[2] = {['chance'] = '±15%', 76130, 76133, 76134, 76135, 76136, 76137, 76131, 76138, 76139, 76140, 76141, 76142},
		},
		['found'] = {
			['location'] = {'Dread Wastes', 'Kun-Lai Summit', 'Townlong Steppes', 'Vale of Eternal Blossoms', 'The Jade Forest', 'Valley of the Four Winds', 'Timeless Isle'},
		},
	};
	
	-- Warlords of Draenor ores --
	[109118] = { -- Blackrock Ore
		['skill'] = 1,
		['found'] = {
			['location'] = {'WOD - Nagrand', 'Talador', 'Frostfire Ridge', 'WOD - Shadowmoon Valley', 'Spires of Arak', 'Gorgrond'},
		},
	};
	
	[109119] = { -- True Iron Ore
		['skill'] = 1,
		['found'] = {
			['location'] = {'WOD - Nagrand', 'Talador', 'Frostfire Ridge', 'WOD - Shadowmoon Valley', 'Spires of Arak', 'Gorgrond'},
		},
	};
	
	-- Legion ores --
	[123918] = { -- Leystone Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 130203},
			[2] = {['chance'] = '±5%', 130172, 130173, 130174, 130175, 130176, 130177},
			[3] = {['chance'] = '±0.5%', 130178, 130179, 130180, 130182, 130183},
		},
		['found'] = {
			['location'] = {'Azsuna', 'Suramar', 'Stormheim', 'Val\'sharah', 'Highmountain', 'Broken Shore'},
		},
	};
	[123919] = { -- Felslate
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 130203},
			[2] = {['chance'] = '±5%', 130172, 130173, 130174, 130175, 130176, 130177},
			[3] = {['chance'] = '±0.5%', 130178, 130179, 130180, 130181, 130182, 130183, 52177},
		},
		['found'] = {
			['location'] = {'Azsuna', 'Suramar', 'Stormheim', 'Val\'sharah', 'Highmountain', 'Broken Shore'},
		},
	};
	[151564] = { -- Empyrium
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 129100},
			[2] = {['chance'] = '±5%', 151579, 151718, 151719, 151722},
			[3] = {['chance'] = '±0.5%', 151720, 151721},
		},
		['found'] = {
			['location'] = {'Krokuun', 'Eredath', 'Antoran Wastes'},
		},
	};
	
	-- Battle for Azeroth ores --
	[152512] = { -- Monelite Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 153700, 153701, 153702, 153703, 153704, 153705},
			[2] = {['chance'] = '±5%', 154120, 154121, 154122, 154123, 154124, 154125, 153706},
		},
		['found'] = {
			['location'] = {'Tiragarde Sound', 'Vol\'dun', 'Stormsong Valley', 'Drustvar', 'Nazmir', 'Zuldazar', 'Mechagon Island'},
		},
	};
	[152513] = { -- Platinum Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 153700, 153701, 153702, 153703, 153704, 153705},
			[2] = {['chance'] = '±10%', 154120, 154121, 154122, 154123, 154124, 154125, 153706},
		},
		['found'] = {
			['location'] = {'Tiragarde Sound', 'Vol\'dun', 'Stormsong Valley', 'Drustvar', 'Nazmir', 'Zuldazar', 'Mechagon Island'},
		},
	};
	[152579] = { -- Storm Silver Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 153700, 153701, 153702, 153703, 153704, 153705},
			[2] = {['chance'] = '±5%', 154120, 154121, 154122, 154123, 154124, 154125, 153706},
		},
		['found'] = {
			['location'] = {'Tiragarde Sound', 'Vol\'dun', 'Stormsong Valley', 'Drustvar', 'Nazmir', 'Zuldazar', 'Mechagon Island'},
		},
	};
	[168185] = { -- Osmenite Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 168188, 168189, 168190, 168191, 168192, 168193, 168635},
		},
		['found'] = {
			['location'] = {'Nazjatar'},
		},
	};
	
	-- Shadowlands ores --
	[171828] = { -- Laestrite Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 173108, 173109, 173110},
			[2] = {['chance'] = '±5%', 173170, 173171, 173172, 173173},
		},
		['found'] = {
			['location'] = {'Ardenweald', 'Bastion', 'Revendreth', 'Maldraxxus'},
		},
	};
	[171829] = { -- Solenium Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 173108, 173109, 173110},
			[2] = {['chance'] = '±5%', 173173},
		},
		['found'] = {
			['location'] = {'Bastion'},
		},
	};
	[171830] = { -- Oxxein Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 173108, 173109, 173110},
			[2] = {['chance'] = '±5%', 173172},
		},
		['found'] = {
			['location'] = {'Maldraxxus'},
		},
	};
	[171831] = { -- Phaedrum Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 173108, 173109, 173110},
			[2] = {['chance'] = '±5%', 173170},
		},
		['found'] = {
			['location'] = {'Ardenweald'},
		},
	};
	[171832] = { -- Sinvyr Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 173108, 173109, 173110},
			[2] = {['chance'] = '±20%', 173171},
		},
		['found'] = {
			['location'] = {'Revendreth'},
		},
	};
	[171833] = { -- Elethium Ore
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 173108, 173109, 173110},
			[2] = {['chance'] = '±25%', 173170, 173171, 173172, 173173},
		},
		['found'] = {
			['location'] = {'The Maw', 'Korthia', 'Ardenweald', 'Maldraxxus', 'Bastion', 'Revendreth'},
			['chance'] = '±10%',
			['node'] = {171828, 171829, 171830, 171831, 171832},
		},
	};
	
	-- Dragonflight ores --
	[190395] = { -- Serevite Ore *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192837, 192840, 192843, 192846, 192849, 192852, 192856, 192859, 192862, 192866, 192869},
		},
		['found'] = {
			['location'] = { 'Dragon Isles' },
		},
	};
	[190396] = { -- Serevite Ore *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192838, 192841, 192844, 192847, 192850, 192853, 192857, 192860, 192863, 192867, 192870},
		},
		['found'] = {
			['location'] = { 'Dragon Isles' },
		},
	};
	[190394] = { -- Serevite Ore *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192839, 192842, 192845, 192848, 192851, 192855, 192858, 192861, 192865, 192868, 192871},
		},
		['found'] = {
			['location'] = { 'Dragon Isles' },
		},
	};
	[189143] = { -- Draconium Ore *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192837, 192840, 192843, 192846, 192849, 192852, 192856, 192859, 192862, 192866, 192869},
		},
		['found'] = {
			['location'] = { 'Dragon Isles' },
		},
	};
	[188658] = { -- Draconium Ore *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192838, 192841, 192844, 192847, 192850, 192853, 192857, 192860, 192863, 192867, 192870},
		},
		['found'] = {
			['location'] = { 'Dragon Isles' },
		},
	};
	[190311] = { -- Draconium Ore *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192839, 192842, 192845, 192848, 192851, 192855, 192858, 192861, 192865, 192868, 192871},
		},
		['found'] = {
			['location'] = { 'Dragon Isles' },
		},
	};
	[190312] = { -- Khaz'gorite Ore *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192837, 192840, 192843, 192846, 192849, 192852, 192856, 192859, 192862, 192866, 192869},
		},
		['found'] = {
			['chance'] = '±10% | ±25%',
			['node'] = {190395, 189143},
		},
	};
	[190313] = { -- Khaz'gorite Ore *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192838, 192841, 192844, 192847, 192850, 192853, 192857, 192860, 192863, 192867, 192870},
		},
		['found'] = {
			['chance'] = '±10% | ±25%',
			['node'] = {190395, 189143},
		},
	};
	[190314] = { -- Khaz'gorite Ore *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 192839, 192842, 192845, 192848, 192851, 192855, 192858, 192861, 192865, 192868, 192871},
		},
		['found'] = {
			['chance'] = '±10% | ±25%',
			['node'] = {190395, 189143},
		},
	};
	
	-- The War Within ores --
	[210930] = { -- Bismuth *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210931] = { -- Bismuth *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210932] = { -- Bismuth *3
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210933] = { -- Aqirite *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498, 212505, 212508 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210934] = { -- Aqirite *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498, 212505, 212508 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210935] = { -- Aqirite *3
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498, 212505, 212508 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210936] = { -- Ironclaw Ore *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498, 212495, 212511 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210937] = { -- Ironclaw Ore *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498, 212495, 212511 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210938] = { -- Ironclaw Ore *3
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498, 212495, 212511 },
		},
		['found'] = {
			['location'] = { 'Azj-Kahet', 'City of Threads', 'Hallowfall', 'The Ringing Deeps' },
		},
	},
	[210939] = { -- Null Stone
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 212498, 212495, 212505, 212508, 212511 },
		},
		['found'] = {
			['chance'] = '±1.5%',
			['node'] = { 210930, 210933, 210936 },
		},
	},
	
	-- Midnight ores --
	[237359] = { -- Refulgent Copper Ore *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 242553, 242554, 242606, 242607 },
			[2] = { ['chance'] = '±2.5% (Prof)', 242608 },
		},
		['found'] = {
			['location'] = { 'Eversong Woods', 'Harandar', 'Zul\'Aman', 'Voidstorm' },
		},
	};
}
D.prospecting = {
	[774] = { -- Malachite
		['skill'] = 20,
		['items'] = {
			[1] = {['chance'] = '±50%', 2770},
		},
	};
	[818] = { -- Tigerseye
		['skill'] = 20,
		['items'] = {
			[1] = {['chance'] = '±50%', 2770},
		},
	};
	[1206] = { -- Moss Agete
		['skill'] = 50,
		['items'] = {
			[1] = {['chance'] = '±35%', 2771},
		},
	};
	[1210] = { -- Shadowgem
		['skill'] = '20|50',
		['items'] = {
			[1] = {['chance'] = '±35%', 2771},
			[2] = {['chance'] = '±10%', 2770},
		},
	};
	[1529] = { -- Jade
		['skill'] = '50|125',
		['items'] = {
			[1] = {['chance'] = '±35%', 2772},
			[2] = {['chance'] = '±5%', 2771},
		},
	};
	[1705] = { -- Lesser Moonstone
		['skill'] = '50|125',
		['items'] = {
			[1] = {['chance'] = '±35%', 2771, 2772},
		},
	};
	[3864] = { -- Citrine
		['skill'] = '50|125|175',
		['items'] = {
			[1] = {['chance'] = '±35%', 2772, 3858},
			[2] = {['chance'] = '±5%', 2771},
		},
	};
	[7909] = { -- Aquamarine
		['skill'] = '50|125|175',
		['items'] = {
			[1] = {['chance'] = '±35%', 3858},
			[2] = {['chance'] = '±5%', 2771, 2772},
		},
	};
	[7910] = { -- Star Ruby
		['skill'] = '125|175|250',
		['items'] = {
			[1] = {['chance'] = '±35%', 3858},
			[2] = {['chance'] = '±15%', 10620},
			[3] = {['chance'] = '±5%', 2772},
		},
	};
	[12361] = { -- Blue Sapphire
		['skill'] = '175|250',
		['items'] = {
			[1] = {['chance'] = '±35%', 10620},
			[3] = {['chance'] = '±5%', 3858},
		},
	};
	[12364] = { -- Huge Emerald
		['skill'] = '175|250',
		['items'] = {
			[1] = {['chance'] = '±35%', 10620},
			[3] = {['chance'] = '±5%', 3858},
		},
	};
	[12799] = { -- Large Opal
		['skill'] = '175|250',
		['items'] = {
			[1] = {['chance'] = '±35%', 10620},
			[3] = {['chance'] = '±5%', 3858},
		},
	};
	[12800] = { -- Azerothian Diamond
		['skill'] = '175|250',
		['items'] = {
			[1] = {['chance'] = '±35%', 10620},
			[3] = {['chance'] = '±5%', 3858},
		},
	};
	
	-- The Burning Crusade gems --
	[21929] = { -- Flame Spessarite
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±15%', 23424, 23425},
		},
	};
	[23077] = { -- Blood Garnet
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±15%', 23424, 23425},
		},
	};
	[23107] = { -- Shadow Draenite
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±15%', 23424, 23425},
		},
	};
	[23079] = { -- Deep Peridot
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±15%', 23424, 23425},
		},
	};
	[23112] = { -- Golden Draenite
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±15%', 23424, 23425},
		},
	};
	[23117] = { -- Azure Moonstone
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±15%', 23424, 23425},
		},
	};
	[23436] = { -- Living Ruby
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±5%', 23425},
			[2] = {['chance'] = '±1.5%', 23424},
		},
	};
	[23437] = { -- Talasite
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±5%', 23425},
			[2] = {['chance'] = '±1.5%', 23424},
		},
	};
	[23438] = { -- Star of Elune
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±5%', 23425},
			[2] = {['chance'] = '±1.5%', 23424},
		},
	};
	[23439] = { -- Noble Topaz
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±5%', 23425},
			[2] = {['chance'] = '±1.5%', 23424},
		},
	};
	[23440] = { -- Dawnstone
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±5%', 23425},
			[2] = {['chance'] = '±1.5%', 23424},
		},
	};
	[23441] = { -- Nightseye
		['skill'] = '275|325',
		['items'] = {
			[1] = {['chance'] = '±5%', 23425},
			[2] = {['chance'] = '±1.5%', 23424},
		},
	};
	[24243] = { -- Adamantite Powder
		['skill'] = 325,
		['items'] = {
			[1] = {['chance'] = '100%', 23425},
		},
	};
	
	-- Wrath of the Lich King gems --
	[36917] = { -- Bloodstone
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±20%', 36909, 36910, 36912},
		},
	};
	[36918] = { -- Scarlet Ruby
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±5%', 36910, 36912},
			[2] = {['chance'] = '±1.5%', 36909},
		},
	};
	[36919] = { -- Cardinal Ruby
		['skill'] = 450,
		['items'] = {
			[1] = {['chance'] = '±5%', 36910},
		},
	};
	[36920] = { -- Sun Crystal
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±20%', 36909, 36910, 36912},
		},
	};
	[36921] = { -- Autumn's Glow
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±5%', 36910, 36912},
			[2] = {['chance'] = '±1.5%', 36909},
		},
	};
	[36922] = { -- King's Amber
		['skill'] = 450,
		['items'] = {
			[1] = {['chance'] = '±5%', 36910},
		},
	};
	[36923] = { -- Chalcedony
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±20%', 36909, 36910, 36912},
		},
	};
	[36924] = { -- Sky Sapphire
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±5%', 36910, 36912},
			[2] = {['chance'] = '±1.5%', 36909},
		},
	};
	[36925] = { -- Majestic Zircon
		['skill'] = 450,
		['items'] = {
			[1] = {['chance'] = '±5%', 36910},
		},
	};
	[36926] = { -- Shadow Crystal
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±20%', 36909, 36910, 36912},
		},
	};
	[36927] = { -- Twilight Opal
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±5%', 36910, 36912},
			[2] = {['chance'] = '±1.5%', 36909},
		},
	};
	[36928] = { -- Dreadstone
		['skill'] = 450,
		['items'] = {
			[1] = {['chance'] = '±5%', 36910},
		},
	};
	[36929] = { -- Huge Citrine
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±20%', 36909, 36910, 36912},
		},
	};
	[36930] = { -- Monarch Topaz
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±5%', 36910, 36912},
			[2] = {['chance'] = '±1.5%', 36909},
		},
	};
	[36931] = { -- Ametrine
		['skill'] = 450,
		['items'] = {
			[1] = {['chance'] = '±5%', 36910},
		},
	};
	[36932] = { -- Dark Jade
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±20%', 36909, 36910, 36912},
		},
	};
	[36933] = { -- Forest Emerald
		['skill'] = '350|400|450',
		['items'] = {
			[1] = {['chance'] = '±5%', 36910, 36912},
			[2] = {['chance'] = '±1.5%', 36909},
		},
	};
	[36934] = { -- Eye of Zul
		['skill'] = 450,
		['items'] = {
			[1] = {['chance'] = '±5%', 36910},
		},
	};
	[46849] = { --Titanium Powder
		['skill'] = 450,
		['items'] = {
			[1] = {['chance'] = '±50%', 36910},
		},
	};
	
	-- Cataclysm gems --
	[52177] = { -- Carnelian
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 53038},
			[2] = {['chance'] = '±15%', 52183, 52185},
		},
	};
	[52178] = { -- Zephyrite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 53038},
			[2] = {['chance'] = '±15%', 52183, 52185},
		},
	};
	[52179] = { -- Alicite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 53038},
			[2] = {['chance'] = '±15%', 52183, 52185},
		},
	};
	[52180] = { -- Nightstone
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 53038},
			[2] = {['chance'] = '±15%', 52183, 52185},
		},
	};
	[52181] = { -- Hessonite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 53038},
			[2] = {['chance'] = '±15%', 52183, 52185},
		},
	};
	[52182] = { -- Jasper
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 53038},
			[2] = {['chance'] = '±15%', 52183, 52185},
		},
	};
	[52190] = { -- Inferno Ruby
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 52183, 52185},
			[2] = {['chance'] = '±1.5%', 53038},
		},
	};
	[52191] = { -- Ocean Sapphire
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 52183, 52185},
			[2] = {['chance'] = '±1.5%', 53038},
		},
	};
	[52192] = { -- Dream Emerald
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 52183, 52185},
			[2] = {['chance'] = '±1.5%', 53038},
		},
	};
	[52193] = { -- Ember Topaz
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 52183, 52185},
			[2] = {['chance'] = '±1.5%', 53038},
		},
	};
	[52194] = { -- Demonseye
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 52183, 52185},
			[2] = {['chance'] = '±1.5%', 53038},
		},
	};
	[52195] = { -- Amberjewel
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 52183, 52185},
			[2] = {['chance'] = '±1.5%', 53038},
		},
	};
	[52327] = { -- Volatile Earth
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±100%', 52183},
		},
	};
	
	-- Mist of Pandaria gems --
	[76130] = { -- Tiger Opal
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 72092, 72093},
			[2] = {['chance'] = '±15%', 72094, 72103},
		},
	};
	[76131] = { -- Primordial Ruby
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 72094, 72103},
			[2] = {['chance'] = '±5%', 72092, 72093},
		},
	};
	[76133] = { -- Lapis Lazuli
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 72092, 72093},
			[2] = {['chance'] = '±15%', 72094, 72103},
		},
	};
	[76134] = { -- Sunstone
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 72092, 72093},
			[2] = {['chance'] = '±15%', 72094, 72103},
		},
	};
	[76135] = { -- Roguestone
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 72092, 72093},
			[2] = {['chance'] = '±15%', 72094, 72103},
		},
	};
	[76136] = { -- Pandarian Garnet
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 72092, 72093},
			[2] = {['chance'] = '±15%', 72094, 72103},
		},
	};
	[76137] = { -- Alexandrite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±25%', 72092, 72093},
			[2] = {['chance'] = '±15%', 72094, 72103},
		},
	};
	[76138] = { -- River's Heart
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 72094, 72103},
			[2] = {['chance'] = '±5%', 72092, 72093},
		},
	};
	[76139] = { -- Wild Jade
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 72094, 72103},
			[2] = {['chance'] = '±5%', 72092, 72093},
		},
	};
	[76140] = { -- Vermilion Onyx
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 72094, 72103},
			[2] = {['chance'] = '±5%', 72092, 72093},
		},
	};
	[76141] = { -- Imperial Amethyst
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 72094, 72103},
			[2] = {['chance'] = '±5%', 72092, 72093},
		},
	};
	[76142] = { -- Sun's Radiance
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 72094, 72103},
			[2] = {['chance'] = '±5%', 72092, 72093},
		},
	};
	[90407] = { -- Sparkling Shard
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 72093, 72094, 72103},
			[2] = {['chance'] = '±80%', 72092},
		},
	};
	
	-- Warlords of Draenor gems --
	-- None --
	
	-- Legion gems --
	[129100] = { -- Gem Chip
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '100%', 151564},
		},
	};
	[129099] = { -- Gem Chip (Red)
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 123918, 123919},
		},
	};
	[130200] = { -- Gem Chip (Orange)
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 123918, 123919},
		},
	};
	[130201] = { -- Gem Chip (Yellow)
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 123918, 123919},
		},
	};
	[130202] = { -- Gem Chip (Green)
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 123918, 123919},
		},
	};
	[130203] = { -- Gem Chip (Blue)
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 123918, 123919},
		},
	};
	[130204] = { -- Gem Chip (Purple)
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 123918, 123919},
		},
	};
	[130172] = { -- Sangrite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 123918, 123919},
		},
	};
	[130173] = { -- Deep Amber
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 123918, 123919},
		},
	};
	[130174] = { -- Azsunite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 123918, 123919},
		},
	};
	[130175] = { -- Chaotic Spinel
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±1.5%', 123918, 123919},
		},
	};
	[130176] = { -- Skystone
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 123918, 123919},
		},
	};
	[130177] = { -- Queen's Opal
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 123918, 123919},
		},
	};
	[130178] = { -- Furystone
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±1%', 123918, 123919},
		},
	};
	[130179] = { -- Eye of Prophecy
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±1%', 123918, 123919},
		},
	};
	[130180] = { -- Dawnlight
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±1%', 123918, 123919},
		},
	};
	[130181] = { -- Pandemonite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±1%', 123919},
		},
	};
	[130182] = { -- Maelstrom Sapphire
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±1%', 123918, 123919},
		},
	};
	[130183] = { -- Shadowruby
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±1%', 123918, 123919},
		},
	};
	[151579] = { -- Labradorite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 151564},
		},
	};
	[151718] = { -- Argulite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 151564},
		},
	};
	[151719] = { -- Lightsphene
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 151564},
		},
	};
	[151720] = { -- Chemirine
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±0.5%', 151564},
		},
	};
	[151721] = { -- Hesselian
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±0.5%', 151564},
		},
	};
	[151722] = { -- Florid Malachite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 151564},
		},
	};
	
	-- Battle for Azeroth gems --
	[153700] = { -- Golden Beryl
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 152512, 152513, 152579},
		},
	};
	[153701] = { -- Rubellite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 152512, 152513, 152579},
		},
	};
	[153702] = { -- Kubiline
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 152512, 152513, 152579},
		},
	};
	[153703] = { -- Solstone
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 152512, 152513, 152579},
		},
	};
	[153704] = { -- Viridium
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 152512, 152513, 152579},
		},
	};
	[153705] = { -- Kyanite
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 152512, 152513, 152579},
		},
	};
	[154120] = { -- Owlseye
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 152513},
			[2] = {['chance'] = '±5%', 152512, 152579},
		},
	};
	[154121] = { -- Scarlet Diamond
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 152513},
			[2] = {['chance'] = '±5%', 152512, 152579},
		},
	};
	[154122] = { -- Tidal Amethyst
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 152513},
			[2] = {['chance'] = '±5%', 152512, 152579},
		},
	};
	[154123] = { -- Amberblaze
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 152513},
			[2] = {['chance'] = '±5%', 152512, 152579},
		},
	};
	[154124] = { -- Laribole
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±10%', 152512, 152513, 152579},
		},
	};
	[154125] = { -- Royal Quartz
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±10%', 152512, 152513, 152579},
		},
	};
	[153706] = { -- Kraken's Eye
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±5%', 152512, 152513, 152579},
		},
	};
	[168188] = { -- Sage Agate
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 168185},
		},
	};
	[168189] = { -- Dark Opal
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 168185},
		},
	};
	[168190] = { -- Lava Lazuli
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 168185},
		},
	};
	[168191] = { -- Sea Currant
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 168185},
		},
	};
	[168192] = { -- Sand Spinel
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 168185},
		},
	};
	[168193] = { -- Azsharine
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±10%', 168185},
		},
	};
	[168195] = { -- Leviathan's Eye
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±15%', 168185},
		},
	};
	
	-- Shadowlands gems --
	[173108] = { -- Oriblase
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 171828, 171829, 171830, 171831, 171832, 171833},
		},
	};
	[173109] = { -- Angerseye
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 171828, 171829, 171830, 171831, 171832, 171833},
		},
	};
	[173110] = { -- Umbryl
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±35%', 171828, 171829, 171830, 171831, 171832, 171833},
		},
	};
	[173170] = { -- Essence of Rebirth
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 171831, 171833},
			[2] = {['chance'] = '±5%', 171828},
		},
	};
	[173171] = { -- Essence of Torment
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 171832, 171833},
			[2] = {['chance'] = '±5%', 171828},
		},
	};
	[173172] = { -- Essence of Servitude
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 171830, 171833},
			[2] = {['chance'] = '±5%', 171828},
		},
	};
	[173173] = { -- Essence of Valor
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '±20%', 171829, 171833},
			[2] = {['chance'] = '±5%', 171828},
		},
	};
	
	-- Dragonflight gems --
	[192837] = { -- Queen's Ruby *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192838] = { -- Queen's Ruby *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192839] = { -- Queen's Ruby *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192840] = { -- Mystic Sapphire *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192841] = { -- Mystic Sapphire *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192842] = { -- Mystic Sapphire *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192843] = { -- Vibrant Emerald *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192844] = { -- Vibrant Emerald *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192845] = { -- Vibrant Emerald *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192846] = { -- Sundered Onyx *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192847] = { -- Sundered Onyx *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192848] = { -- Sundered Onyx *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192849] = { -- Eternity Amber *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192850] = { -- Eternity Amber *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192851] = { -- Eternity Amber *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192852] = { -- Alexstraszite *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192853] = { -- Alexstraszite *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192855] = { -- Alexstraszite *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192856] = { -- Malygite *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192857] = { -- Malygite *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192858] = { -- Malygite *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192859] = { -- Ysemerald *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192860] = { -- Ysemerald *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192861] = { -- Ysemerald *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192862] = { -- Neltharite *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192863] = { -- Neltharite *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192865] = { -- Neltharite *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192866] = { -- Nozdorite *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192867] = { -- Nozdorite *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192868] = { -- Nozdorite *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	[192869] = { -- Illimited Diamond *1
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190395, 189143, 190312},
		},
	};
	[192870] = { -- Illimited Diamond *2
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190396, 188658, 190313},
		},
	};
	[192871] = { -- Illimited Diamond *3
		['skill'] = 1,
		['items'] = {
			[1] = {['chance'] = '?% (Unknown)', 190394, 190311, 190314},
		},
	};
	-- Dragonflight gems --
	[212495] = { -- Radiant Ruby
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 210936, 210939 },
		},
	},
	[212498] = { -- Ambivalent Amber
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 210930, 210939 },
		},
	},
	[212505] = { -- Extravagant Emerald
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 210933, 210939 },
		},
	},
	[212508] = { -- Stunning Sapphire
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 210933, 210939 },
		},
	},
	[212511] = { -- Ostentatious Onyx
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '?% (Unknown)', 210936, 210939 },
		},
	},
	
	-- Midnight gems --
	[242553] = { -- Sanguine Garnet *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237359 },
			[2] = { ['chance'] = '±15%', 237364 },
		},
	},
	[242723] = { -- Sanguine Garnet *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237361 },
			[2] = { ['chance'] = '±15%', 237365 },
		},
	},
	[242554] = { -- Amani Lapis *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237359 },
			[2] = { ['chance'] = '±15%', 237364 },
		},
	},
	[242722] = { -- Amani Lapis *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237361 },
			[2] = { ['chance'] = '±15%', 237365 },
		},
	},
	[242606] = { -- Tenebrous Amethyst *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237359 },
			[2] = { ['chance'] = '±15%', 237362 },
		},
	},
	[242721] = { -- Tenebrous Amethyst *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237361 },
			[2] = { ['chance'] = '±15%', 237363 },
		},
	},
	[242607] = { -- Harandar Peridot *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237359 },
			[2] = { ['chance'] = '±15%', 237362 },
		},
	},
	[242720] = { -- Harandar Peridot *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237361 },
			[2] = { ['chance'] = '±15%', 237363 },
		},
	},
	[242610] = { -- Flawless Harandar Peridot *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±15%', 237362, 237366 },
		},
	},
	[242726] = { -- Flawless Harandar Peridot *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±10%', 237363, 237366 },
		},
	},
	[242611] = { -- Flawless Tenebrous Amethyst *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±15%', 237362, 237366 },
		},
	},
	[242725] = { -- Flawless Tenebrous Amethyst *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±15%', 237363, 237366 },
		},
	},
	[242612] = { -- Flawless Amani Lapis *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±15%', 237364, 237366 },
		},
	},
	[242727] = { -- Flawless Amani Lapis *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±15%', 237365, 237366 },
		},
	},
	[242613] = { -- Flawless Sanguine Garnet *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±15%', 237364, 237366 },
		},
	},
	[242724] = { -- Flawless Sanguine Garnet *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±15%', 237365, 237366 },
		},
	},
	[242608] = { -- Eversong Diamond *1
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±2.5% (Prof)', 237359 },
			[2] = { ['chance'] = '±5% (Prof)', 237362, 237364 },
			[3] = { ['chance'] = '±20% (Prof)', 237366 },
		},
	},
	[242712] = { -- Eversong Diamond *2
		['skill'] = 1,
		['items'] = {
			[1] = { ['chance'] = '±2.5% (Prof)', 237361 },
			[2] = { ['chance'] = '±5% (Prof)', 237363, 237365 },
			[3] = { ['chance'] = '±20% (Prof)', 237366 },
		},
	},
}
D.gear = {
		[2] = {
			{
				['min'] = 5, ['max'] = 15, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 1,
					['items'] = {
						[1] = {['chance'] = '±75%', 10938},
						[2] = {['chance'] = '±25%', 10940},
					},
				},
				['armor'] = {
					['skill'] = 1,
					['items'] = {
						[1] = {['chance'] = '±75%', 10940},
						[2] = {['chance'] = '±25%', 10938},
					}
				}
			},
			{
				['min'] = 16, ['max'] = 25, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 25,
					['items'] = {
						[1] = {['chance'] = '±75%', 10939},
						[2] = {['chance'] = '±25%', 10940},
						[3] = {['chance'] = '±15% (21+)', 10978},
					},
				},
				['armor'] = {
					['skill'] = 25,
					['items'] = {
						[1] = {['chance'] = '±75%', 10940},
						[2] = {['chance'] = '±25%', 10939},
						[3] = {['chance'] = '±15% (21+)', 10978},
					}
				}
			},
			{
				['min'] = 26, ['max'] = 30, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 50,
					['items'] = {
						[1] = {['chance'] = '±75%', 10998},
						[2] = {['chance'] = '±25%', 11083},
						[3] = {['chance'] = '±15%', 11084},
					},
				},
				['armor'] = {
					['skill'] = 50,
					['items'] = {
						[1] = {['chance'] = '±75%', 11083},
						[2] = {['chance'] = '±25%', 10998},
						[3] = {['chance'] = '±15%', 11084},
					}
				}
			},
			{
				['min'] = 31, ['max'] = 35, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 75,
					['items'] = {
						[1] = {['chance'] = '±75%', 11082},
						[2] = {['chance'] = '±25%', 11083},
						[3] = {['chance'] = '±15%', 11138},
					},
				},
				['armor'] = {
					['skill'] = 75,
					['items'] = {
						[1] = {['chance'] = '±75%', 11083},
						[2] = {['chance'] = '±25%', 11082},
						[3] = {['chance'] = '±15%', 11138},
					}
				}
			},
			{
				['min'] = 36, ['max'] = 40, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 100,
					['items'] = {
						[1] = {['chance'] = '±75%', 11134},
						[2] = {['chance'] = '±25%', 11137},
						[3] = {['chance'] = '±15%', 11139},
					},
				},
				['armor'] = {
					['skill'] = 100,
					['items'] = {
						[1] = {['chance'] = '±75%', 11137},
						[2] = {['chance'] = '±25%', 11134},
						[3] = {['chance'] = '±15%', 11139},
					}
				}
			},
			{
				['min'] = 41, ['max'] = 45, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 125,
					['items'] = {
						[1] = {['chance'] = '±75%', 11135},
						[2] = {['chance'] = '±25%', 11137},
						[3] = {['chance'] = '±15%', 11177},
					},
				},
				['armor'] = {
					['skill'] = 125,
					['items'] = {
						[1] = {['chance'] = '±75%', 11137},
						[2] = {['chance'] = '±25%', 11135},
						[3] = {['chance'] = '±15%', 11177},
					}
				}
			},
			{
				['min'] = 46, ['max'] = 50, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 150,
					['items'] = {
						[1] = {['chance'] = '±75%', 11174},
						[2] = {['chance'] = '±25%', 11176},
						[3] = {['chance'] = '±5%', 11178},
					},
				},
				['armor'] = {
					['skill'] = 150,
					['items'] = {
						[1] = {['chance'] = '±75%', 11176},
						[2] = {['chance'] = '±25%', 11174},
						[3] = {['chance'] = '±15%', 11178},
					}
				}
			},
			{
				['min'] = 51, ['max'] = 55, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 175,
					['items'] = {
						[1] = {['chance'] = '±75%', 11175},
						[2] = {['chance'] = '±25%', 11176},
						[3] = {['chance'] = '±5%', 14343},
					},
				},
				['armor'] = {
					['skill'] = 175,
					['items'] = {
						[1] = {['chance'] = '±75%', 11176},
						[2] = {['chance'] = '±25%', 11175},
						[3] = {['chance'] = '±15%', 14343},
					}
				}
			},
			{
				['min'] = 56, ['max'] = 60, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 200,
					['items'] = {
						[1] = {['chance'] = '±75%', 16202},
						[2] = {['chance'] = '±25%', 16204},
						[3] = {['chance'] = '±5%', 14344},
					},
				},
				['armor'] = {
					['skill'] = 200,
					['items'] = {
						[1] = {['chance'] = '±75%', 16204},
						[2] = {['chance'] = '±25%', 16202},
						[3] = {['chance'] = '±15%', 14344},
					}
				}
			},
			{
				['min'] = 61, ['max'] = 65, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '±75%', 16203},
						[2] = {['chance'] = '±25%', 16204},
						[3] = {['chance'] = '±5%', 14344},
					},
				},
				['armor'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '±75%', 16204},
						[2] = {['chance'] = '±25%', 16203},
						[3] = {['chance'] = '±15%', 14344},
					}
				}
			},
			
			-- The Burning Crusade results --
			{
				['min'] = 80, ['max'] = 99, ['expansion'] = 1,
				['weapon'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '±75%', 22447},
						[2] = {['chance'] = '±25%', 22445},
						[3] = {['chance'] = '±5%', 22448},
					},
				},
				['armor'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '±75%', 22445},
						[2] = {['chance'] = '±25%', 22447},
						[3] = {['chance'] = '±5%', 22448},
					}
				}
			},
			{
				['min'] = 100, ['max'] = 120, ['expansion'] = 1,
				['weapon'] = {
					['skill'] = 275,
					['items'] = {
						[1] = {['chance'] = '±75%', 22446},
						[2] = {['chance'] = '±25%', 22445},
						[3] = {['chance'] = '±5%', 22449},
					},
				},
				['armor'] = {
					['skill'] = 275,
					['items'] = {
						[1] = {['chance'] = '±75%', 22445},
						[2] = {['chance'] = '±25%', 22446},
						[3] = {['chance'] = '±5%', 22449},
					}
				}
			},
			
			-- The Wrath of the Lich King results --
			{
				['min'] = 130, ['max'] = 151, ['expansion'] = 2,
				['weapon'] = {
					['skill'] = 325,
					['items'] = {
						[1] = {['chance'] = '±75%', 34054},
						[2] = {['chance'] = '±25%', 34056},
						[3] = {['chance'] = '±5%', 34053},
					},
				},
				['armor'] = {
					['skill'] = 325,
					['items'] = {
						[1] = {['chance'] = '±75%', 34056},
						[2] = {['chance'] = '±25%', 34054},
						[3] = {['chance'] = '±5%', 34053},
					}
				}
			},
			{
				['min'] = 152, ['max'] = 200, ['expansion'] = 2,
				['weapon'] = {
					['skill'] = 350,
					['items'] = {
						[1] = {['chance'] = '±75%', 34054},
						[2] = {['chance'] = '±25%', 34055},
						[3] = {['chance'] = '±5%', 34052},
					},
				},
				['armor'] = {
					['skill'] = 350,
					['items'] = {
						[1] = {['chance'] = '±75%', 34055},
						[2] = {['chance'] = '±25%', 34054},
						[3] = {['chance'] = '±5%', 34052},
					}
				}
			},
			
			-- The Cataclysm results --
			{
				['min'] = 272, ['max'] = 305, ['expansion'] = 3,
				['weapon'] = {
					['skill'] = 425,
					['items'] = {
						[1] = {['chance'] = '±75%', 52555},
						[2] = {['chance'] = '±25%', 52718},
					},
				},
				['armor'] = {
					['skill'] = 425,
					['items'] = {
						[1] = {['chance'] = '±75%', 52718},
						[2] = {['chance'] = '±25%', 52555},
					}
				}
			},
			{
				['min'] = 306, ['max'] = 333, ['expansion'] = 3,
				['weapon'] = {
					['skill'] = 425,
					['items'] = {
						[1] = {['chance'] = '±75%', 52555},
						[2] = {['chance'] = '±25%', 52719},
					},
				},
				['armor'] = {
					['skill'] = 425,
					['items'] = {
						[1] = {['chance'] = '±75%', 52719},
						[2] = {['chance'] = '±25%', 52555},
					}
				}
			},
			
			-- Mist of Pandaria results --
			{
				['min'] = 364, ['max'] = 437, ['expansion'] = 4,
				['weapon'] = {
					['skill'] = 475,
					['items'] = {
						[1] = {['chance'] = '±75%', 74249},
						[2] = {['chance'] = '±25%', 74250},
					},
				},
				['armor'] = {
					['skill'] = 475,
					['items'] = {
						[1] = {['chance'] = '±75%', 74249},
						[2] = {['chance'] = '±25%', 74250},
					}
				}
			},
		},
		[3] = {
			{
				['min'] = 16, ['max'] = 25, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 25,
					['items'] = {
						[1] = {['chance'] = '100%', 10978},
					},
				},
				['armor'] = {
					['skill'] = 25,
					['items'] = {
						[1] = {['chance'] = '100%', 10978},
					}
				}
			},
			{
				['min'] = 26, ['max'] = 30, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 50,
					['items'] = {
						[1] = {['chance'] = '100%', 11084},
					},
				},
				['armor'] = {
					['skill'] = 50,
					['items'] = {
						[1] = {['chance'] = '100%', 11084},
					}
				}
			},
			{
				['min'] = 31, ['max'] = 35, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 75,
					['items'] = {
						[1] = {['chance'] = '100%', 11138},
					},
				},
				['armor'] = {
					['skill'] = 75,
					['items'] = {
						[1] = {['chance'] = '100%', 11138},
					}
				}
			},
			{
				['min'] = 36, ['max'] = 40, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 100,
					['items'] = {
						[1] = {['chance'] = '100%', 11139},
					},
				},
				['armor'] = {
					['skill'] = 100,
					['items'] = {
						[1] = {['chance'] = '100%', 11139},
					}
				}
			},
			{
				['min'] = 41, ['max'] = 45, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 125,
					['items'] = {
						[1] = {['chance'] = '±100%', 11177},
					},
				},
				['armor'] = {
					['skill'] = 125,
					['items'] = {
						[1] = {['chance'] = '±100%', 11177},
					}
				}
			},
			{
				['min'] = 46, ['max'] = 50, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 150,
					['items'] = {
						[1] = {['chance'] = '100%', 11178},
					},
				},
				['armor'] = {
					['skill'] = 150,
					['items'] = {
						[1] = {['chance'] = '100%', 11178},
					}
				}
			},
			{
				['min'] = 51, ['max'] = 55, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 175,
					['items'] = {
						[1] = {['chance'] = '100%', 14343},
					},
				},
				['armor'] = {
					['skill'] = 175,
					['items'] = {
						[1] = {['chance'] = '100%', 14343},
					}
				}
			},
			{
				['min'] = 56, ['max'] = 60, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 200,
					['items'] = {
						[1] = {['chance'] = '100%', 14344},
					},
				},
				['armor'] = {
					['skill'] = 200,
					['items'] = {
						[1] = {['chance'] = '100%', 14344},
					}
				}
			},
			{
				['min'] = 61, ['max'] = 65, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '100%', 14344},
					},
				},
				['armor'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '100%', 14344},
					}
				}
			},
			
			-- The Burning Crusade results --
			{
				['min'] = 80, ['max'] = 99, ['expansion'] = 1,
				['weapon'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '100%', 22448},
					},
				},
				['armor'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '100%', 22448},
					}
				}
			},
			{
				['min'] = 100, ['max'] = 120, ['expansion'] = 1,
				['weapon'] = {
					['skill'] = 275,
					['items'] = {
						[1] = {['chance'] = '100%', 22449},
					},
				},
				['armor'] = {
					['skill'] = 275,
					['items'] = {
						[1] = {['chance'] = '100%', 22449},
					}
				}
			},
			
			-- The Wrath of the Lich King results --
			{
				['min'] = 130, ['max'] = 151, ['expansion'] = 2,
				['weapon'] = {
					['skill'] = 325,
					['items'] = {
						[1] = {['chance'] = '100%', 34053},
					},
				},
				['armor'] = {
					['skill'] = 325,
					['items'] = {
						[1] = {['chance'] = '100%', 34053},
					}
				}
			},
			{
				['min'] = 152, ['max'] = 200, ['expansion'] = 2,
				['weapon'] = {
					['skill'] = 350,
					['items'] = {
						[1] = {['chance'] = '100%', 34052},
					},
				},
				['armor'] = {
					['skill'] = 350,
					['items'] = {
						[1] = {['chance'] = '100%', 34052},
					}
				}
			},
			
			-- The Cataclysm results --
			{
				['min'] = 288, ['max'] = 316, ['expansion'] = 3,
				['weapon'] = {
					['skill'] = 450,
					['items'] = {
						[1] = {['chance'] = '100%', 52720},
					},
				},
				['armor'] = {
					['skill'] = 450,
					['items'] = {
						[1] = {['chance'] = '100%', 52720},
					}
				}
			},
			{
				['min'] = 318, ['max'] = 346, ['expansion'] = 3,
				['weapon'] = {
					['skill'] = 450,
					['items'] = {
						[1] = {['chance'] = '100%', 52721},
					},
				},
				['armor'] = {
					['skill'] = 450,
					['items'] = {
						[1] = {['chance'] = '100%', 52721},
					}
				}
			},
			
			-- Mist of Pandaria results --
			{
				['min'] = 393, ['max'] = 424, ['expansion'] = 4,
				['weapon'] = {
					['skill'] = 525,
					['items'] = {
						[1] = {['chance'] = '±95%', 74252},
						[2] = {['chance'] = '±5%', 74247},
					},
				},
				['armor'] = {
					['skill'] = 525,
					['items'] = {
						[1] = {['chance'] = '±95%', 74252},
						[2] = {['chance'] = '±5%', 74247},
					}
				}
			},
		},
		[4] = {
			{
				['min'] = 56, ['max'] = 80, ['expansion'] = 0,
				['weapon'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '100%', 20725},
					},
				},
				['armor'] = {
					['skill'] = 225,
					['items'] = {
						[1] = {['chance'] = '100%', 20725},
					}
				}
			},
			
			-- The Burning Crusade results --
			{
				['min'] = 95, ['max'] = 164, ['expansion'] = 1,
				['weapon'] = {
					['skill'] = 300,
					['items'] = {
						[1] = {['chance'] = '100%', 22450},
					},
				},
				['armor'] = {
					['skill'] = 300,
					['items'] = {
						[1] = {['chance'] = '100%', 22450},
					}
				}
			},
			
			-- The Wrath of the Lich King results --
			{
				['min'] = 165, ['max'] = 264, ['expansion'] = 2,
				['weapon'] = {
					['skill'] = 375,
					['items'] = {
						[1] = {['chance'] = '100%', 34057},
					},
				},
				['armor'] = {
					['skill'] = 375,
					['items'] = {
						[1] = {['chance'] = '100%', 34057},
					}
				}
			},
			
			-- The Cataclysm results --
			{
				['min'] = 353, ['max'] = 372, ['expansion'] = 3,
				['weapon'] = {
					['skill'] = 475,
					['items'] = {
						[1] = {['chance'] = '100%', 52722},
					},
				},
				['armor'] = {
					['skill'] = 475,
					['items'] = {
						[1] = {['chance'] = '100%', 52722},
					}
				}
			},
			
			-- Mist of Pandaria results --
			{
				['min'] = 420, ['max'] = 566, ['expansion'] = 4,
				['weapon'] = {
					['skill'] = 575,
					['items'] = {
						[1] = {['chance'] = '100%', 74248},
					},
				},
				['armor'] = {
					['skill'] = 1,
					['items'] = {
						[1] = {['chance'] = '100%', 74248},
					}
				}
			},
		},
	}
D.disenchant = {
		[10938] = { -- Lesser Magic Essence
			['skill'] = 1,
			['min'] = 5, ['max'] = 15,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[10939] = { -- Greater Magic Essence
			['skill'] = 25,
			['min'] = 16, ['max'] = 25,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[10940] = { -- Strange Dust
			['skill'] = '1|25',
			['min'] = 5, ['max'] = 25,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[10978] = { -- Small Glimmering Shard
			['skill'] = 25,
			['min'] = 21, ['max'] = 25,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±15%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[10998] = { -- Lesser Astral Essence
			['skill'] = 50,
			['min'] = 26, ['max'] = 30,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[11082] = { -- Greater Astral Essence
			['skill'] = 75,
			['min'] = 31, ['max'] = 35,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[11083] = { -- Soul Dust
			['skill'] = '50|75',
			['min'] = 26, ['max'] = 35,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[11084] = { -- Large Glimmering Shard
			['skill'] = 75,
			['min'] = 26, ['max'] = 30,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±15%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[11134] = { -- Lesser Mystic Essence
			['skill'] = 100,
			['min'] = 36, ['max'] = 40,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[11135] = { -- Greater Mystic Essence
			['skill'] = 125,
			['min'] = 41, ['max'] = 45,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[11137] = { -- Vision Dust
			['skill'] = '100|125',
			['min'] = 36, ['max'] = 45,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[11138] = { -- Small Glowing Shard
			['skill'] = 100,
			['min'] = 31, ['max'] = 35,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±15%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[11139] = { -- Large Glowing Shard
			['skill'] = 125,
			['min'] = 36, ['max'] = 40,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±15%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[11174] = { -- Lesser Nether Essence
			['skill'] = 150,
			['min'] = 46, ['max'] = 50,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[11175] = { -- Greater Nether Essence
			['skill'] = 175,
			['min'] = 51, ['max'] = 55,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[11176] = { -- Dream Dust
			['skill'] = '150|175',
			['min'] = 46, ['max'] = 55,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[11177] = { -- Small Radiant Shard
			['skill'] = 150,
			['min'] = 41, ['max'] = 45,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±15%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[11178] = { -- Large Radiant Shard
			['skill'] = 175,
			['min'] = 46, ['max'] = 50,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±15%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[14343] = { -- Small Brilliant Shard
			['skill'] = 200,
			['min'] = 51, ['max'] = 55,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±5%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[14344] = { -- Large Brilliant Shard
			['skill'] = 225,
			['min'] = 56, ['max'] = 65,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 4, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[3] = {['chance'] = '±5%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[16202] = { -- Lesser Eternal Essence
			['skill'] = 200,
			['min'] = 56, ['max'] = 60,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[16203] = { -- Greater Eternal Essence
			['skill'] = 225,
			['min'] = 61, ['max'] = 65,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[16204] = { -- Illusion Dust
			['skill'] = '200|225',
			['min'] = 56, ['max'] = 65,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[20725] = { -- Nexus Crystal
			['skill'] = '200|225',
			['min'] = 56, ['max'] = 80,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 4, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±15%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		
		-- The Burning Crusade materials --
		[22445] = { -- Arcane Dust
			['skill'] = '225|275',
			['min'] = 80, ['max'] = 99,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[22446] = { -- Greater Planar Essence
			['skill'] = 275,
			['min'] = 100, ['max'] = 120,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[22447] = { -- Lesser Planar Essence
			['skill'] = 225,
			['min'] = 80, ['max'] = 99,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[22448] = { -- Small Prismatic Shard
			['skill'] = 225,
			['min'] = 80, ['max'] = 99,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±5%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[22449] = { -- Large Prismatic Shard
			['skill'] = 275,
			['min'] = 100, ['max'] = 120,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±5%', ['quality'] = 2, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[22450] = { -- Void Crystal
			['skill'] = 275,
			['min'] = 95, ['max'] = 164,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 4, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±0.5%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		
		-- Wrath of the Lick King materials --
		[34054] = { -- Infinite Dust
			['skill'] = '325|350',
			['min'] = 130, ['max'] = 200,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[34055] = { -- Greater Cosmic Essence
			['skill'] = 350,
			['min'] = 152, ['max'] = 200,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[34056] = { -- Lesser Cosmic Essence
			['skill'] = 325,
			['min'] = 130, ['max'] = 151,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[34053] = { -- Small Dream Shard
			['skill'] = 325,
			['min'] = 130, ['max'] = 151,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±5%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[34052] = { -- Dream Shard
			['skill'] = 325,
			['min'] = 152, ['max'] = 200,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±5%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[34057] = { -- Abyss Crystal
			['skill'] = 375,
			['min'] = 165, ['max'] = 264,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 4, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±0.5%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		
		-- Cataclysm materials --
		[52555] = { -- Hypnotic Dust
			['skill'] = 425,
			['min'] = 272, ['max'] = 333,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[52718] = { -- Lesser Celestial Essence
			['skill'] = 425,
			['min'] = 272, ['max'] = 305,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[52719] = { -- Greater Celestial Essence
			['skill'] = 425,
			['min'] = 306, ['max'] = 333,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[52720] = { -- Small Heavenly Shard
			['skill'] = 450,
			['min'] = 288, ['max'] = 316,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[52721] = { -- Heavenly Shard
			['skill'] = 450,
			['min'] = 318, ['max'] = 346,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[52722] = { -- Maelstrom Crystal
			['skill'] = 475,
			['min'] = 353, ['max'] = 372,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 4, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		
		-- Mist of Pandaria materials --
		[74247] = { -- Ethereal Shard
			['skill'] = 525,
			['min'] = 393, ['max'] = 424,
			['text'] = {
				[1] = {['chance'] = '±95% (39)', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±5% (38)', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[74248] = { -- Sha Crystal
			['skill'] = 575,
			['min'] = 420, ['max'] = 566,
			['text'] = {
				[1] = {['chance'] = '100%', ['quality'] = 4, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
		[74249] = { -- Spirit Dust
			['skill'] = 475,
			['min'] = 364, ['max'] = 437,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
			},
		},
		[74250] = { -- Mysterious Essence
			['skill'] = 475,
			['min'] = 364, ['max'] = 437,
			['text'] = {
				[1] = {['chance'] = '±75%', ['quality'] = 2, ['type'] = {_G['WEAPON']}},
				[2] = {['chance'] = '±25%', ['quality'] = 2, ['type'] = {_G['ARMOR']}},
			},
		},
		[74252] = { -- Small Ethereal Shard
			['skill'] = 525,
			['min'] = 393, ['max'] = 424,
			['text'] = {
				[1] = {['chance'] = '±95% (38)', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
				[2] = {['chance'] = '±5% (39)', ['quality'] = 3, ['type'] = {_G['ARMOR'], _G['WEAPON']}},
			},
		},
	}
D.mapIDs = {
	['Durotar'] = {
		[1] = 1411,
		[2] = 1
	},
	['Mulgore'] = {
		[1] = 1412,
		[2] = 7
	},
	['Northern Barrens'] = {
		[1] = nil,
		[2] = 10
	},
	['Arathi Highlands'] = {
		[1] = 1417,
		[2] = 14
	},
	['Badlands'] = {
		[1] = 1418,
		[2] = 15
	},
	['The Barrens'] = {
		[1] = 17,
		[2] = nil
	},
	['Blasted Lands'] = {
		[1] = 1419,
		[2] = 17
	},
	['Tirisfal Glades'] = {
		[1] = 1420,
		[2] = 18
	},
	['Silverpine Forest'] = {
		[1] = 1421,
		[2] = 21
	},
	['Western Plaguelands'] = {
		[1] = 1422,
		[2] = 22
	},
	['Eastern Plaguelands'] = {
		[1] = 1423,
		[2] = 23
	},
	['Hillsbrad Foothills'] = {
		[1] = 1424,
		[2] = 25
	},
	['The Hinterlands'] = {
		[1] = 1425,
		[2] = 26
	},
	['Dun Morogh'] = {
		[1] = 1426,
		[2] = 27
	},
	['New Tinkertown'] = {
		[1] = nil,
		[2] = 30
	},
	['Searing Gorge'] = {
		[1] = 1427,
		[2] = 32
	},
	['Burning Steppes'] = {
		[1] = 1428,
		[2] = 36
	},
	['Elwynn Forest'] = {
		[1] = 1429,
		[2] = 37
	},
	['Duskwood'] = {
		[1] = 1431,
		[2] = 47
	},
	['Loch Modan'] = {
		[1] = 1432,
		[2] = 48
	},
	['Redridge Mountains'] = {
		[1] = 1433,
		[2] = 49
	},
	['Northern Stranglethorn'] = {
		[1] = nil,
		[2] = 50
	},
	['Swamp of Sorrows'] = {
		[1] = 1435,
		[2] = 51
	},
	['Westfall'] = {
		[1] = 1436,
		[2] = 52
	},
	['Wetlands'] = {
		[1] = 1437,
		[2] = 56
	},
	['Teldrassil'] = {
		[1] = 1438,
		[2] = 57
	},
	['Darkshore'] = {
		[1] = 1439,
		[2] = 62
	},
	['Ashenvale'] = {
		[1] = 1440,
		[2] = 63
	},
	['Thousand Needles'] = {
		[1] = 1441,
		[2] = 64
	},
	['Stonetalon Mountains'] = {
		[1] = 1442,
		[2] = 65
	},
	['Desolace'] = {
		[1] = 1443,
		[2] = 66
	},
	['Feralas'] = {
		[1] = 1444,
		[2] = 69
	},
	['Dustwallow Marsh'] = {
		[1] = 1445,
		[2] = 70
	},
	['Tanaris'] = {
		[1] = 1446,
		[2] = 71
	},
	['Azshara'] = {
		[1] = 1447,
		[2] = 76
	},
	['Felwood'] = {
		[1] = 1448,
		[2] = 77
	},
	['Un\'Goro Crater'] = {
		[1] = 1448,
		[2] = 78
	},
	['Silithus'] = {
		[1] = 1451,
		[2] = 81
	},
	['Winterspring'] = {
		[1] = 1452,
		[2] = 83
	},
	['Eversong Woods'] = {
		[1] = 1941,
		[2] = 2395
	},
	['Ghostlands'] = {
		[1] = 1942,
		[2] = 95
	},
	['Azuremyst Isle'] = {
		[1] = 1943,
		[2] = 97
	},
	['Hellfire Peninsula'] = {
		[1] = 1944,
		[2] = 100
	},
	['Zangarmarsh'] = {
		[1] = 1946,
		[2] = 102
	},
	['Shadowmoon Valley'] = {
		[1] = 1948,
		[2] = 104
	},
	['Blade\'s Edge Mountains'] = {
		[1] = 1949,
		[2] = 105
	},
	['Bloodmyst Isle'] = {
		[1] = 1950,
		[2] = 106
	},
	['Nagrand'] = {
		[1] = 1951,
		[2] = 107
	},
	['Terokkar Forest'] = {
		[1] = 1952,
		[2] = 108
	},
	['Netherstorm'] = {
		[1] = 1953,
		[2] = 109
	},
	['Borean Tundra'] = {
		[1] = 114,
		[2] = 114
	},
	['Dragonblight'] = {
		[1] = 115,
		[2] = 115
	},
	['Grizzly Hills'] = {
		[1] = 116,
		[2] = 116
	},
	['Howling Fjord'] = {
		[1] = 117,
		[2] = 117
	},
	['Icecrown'] = {
		[1] = 118,
		[2] = 118
	},
	['Sholazar Basin'] = {
		[1] = 119,
		[2] = 119
	},
	['The Storm Peaks'] = {
		[1] = 120,
		[2] = 120
	},
	['Zul\'Drak'] = {
		[1] = 121,
		[2] = 121
	},
	['Isle of Quel\'Danas'] = {
		[1] = 1957,
		[2] = 122
	},
	['Wintergrasp'] = {
		[1] = 123,
		[2] = 123
	},
	['Crystalsong Forest'] = {
		[1] = 127,
		[2] = 127
	},
	['The Lost Isles'] = {
		[1] = nil,
		[2] = 174
	},
	['Gilneas'] = {
		[1] = nil,
		[2] = 179
	},
	['Mount Hyjal'] = {
		[1] = nil,
		[2] = 198
	},
	['Southern Barrens'] = {
		[1] = nil,
		[2] = 199
	},
	['Kelp\'thar Forest'] = {
		[1] = nil,
		[2] = 201
	},
	['Gilneas City'] = {
		[1] = nil,
		[2] = 202
	},
	['Abyssal Depths'] = {
		[1] = nil,
		[2] = 204
	},
	['Shimmering Expanse'] = {
		[1] = nil,
		[2] = 205
	},
	['Deepholm'] = {
		[1] = nil,
		[2] = 207
	},
	['The Cape of Stranglethorn'] = {
		[1] = nil,
		[2] = 210
	},
	['Stranglethorn Vale'] = {
		[1] = 1434,
		[2] = 224
	},
	['Twilight Highlands'] = {
		[1] = nil,
		[2] = 241
	},
	['Tol Barad'] = {
		[1] = nil,
		[2] = 244
	},
	['Tol Barad Peninsula'] = {
		[1] = nil,
		[2] = 245
	},
	['Uldum'] = {
		[1] = nil,
		[2] = 249
	},
	['Auchenai Crypts'] = {
		[1] = 256,
		[2] = 256
	},
	['Sethekk Halls'] = {
		[1] = 258,
		[2] = 258
	},
	['The Steamvault'] = {
		[1] = 258,
		[2] = 258
	},
	['Shadow Labyrinth'] = {
		[1] = 260,
		[2] = 260
	},
	['The Slave Pens'] = {
		[1] = 265,
		[2] = 265
	},
	['The Botanica'] = {
		[1] = 266,
		[2] = 266
	},
	['Mana-Tombs'] = {
		[1] = 272,
		[2] = 272
	},
	['The Jade Forest'] = {
		[1] = nil,
		[2] = 371
	},
	['Valley of the Four Winds'] = {
		[1] = nil,
		[2] = 376
	},
	['The Wandering Isle'] = {
		[1] = nil,
		[2] = 378
	},
	['Kun-Lai Summit'] = {
		[1] = nil,
		[2] = 379
	},
	['Townlong Steppes'] = {
		[1] = nil,
		[2] = 388
	},
	['Vale of Eternal Blossoms'] = {
		[1] = nil,
		[2] = 390
	},
	['Krasarang Wilds'] = {
		[1] = nil,
		[2] = 418
	},
	['Dread Wastes'] = {
		[1] = nil,
		[2] = 422
	},
	['The Veiled Stair'] = {
		[1] = nil,
		[2] = 423
	},
	['Frostfire Ridge'] = {
		[1] = nil,
		[2] = 525
	},
	['Talador'] = {
		[1] = nil,
		[2] = 535
	},
	['WOD - Shadowmoon Valley'] = {
		[1] = nil,
		[2] = 539
	},
	['Spires of Arak'] = {
		[1] = nil,
		[2] = 542
	},
	['Gorgrond'] = {
		[1] = nil,
		[2] = 543
	},
	['WOD - Nagrand'] = {
		[1] = nil,
		[2] = 550
	},
	['Timeless Isle'] = {
		[1] = nil,
		[2] = 554
	},
	['Ashran'] = {
		[1] = nil,
		[2] = 588
	},
	['Azsuna'] = {
		[1] = nil,
		[2] = 630
	},
	['Stormheim'] = {
		[1] = nil,
		[2] = 634
	},
	['Val\'sharah'] = {
		[1] = nil,
		[2] = 641
	},
	['Broken Shore'] = {
		[1] = nil,
		[2] = 646
	},
	['Highmountain'] = {
		[1] = nil,
		[2] = 650
	},
	['Suramar'] = {
		[1] = nil,
		[2] = 680
	},
	['Krokuun'] = {
		[1] = nil,
		[2] = 830
	},
	['Zuldazar'] = {
		[1] = nil,
		[2] = 862
	},
	['Nazmir'] = {
		[1] = nil,
		[2] = 863
	},
	['Vol\'dun'] = {
		[1] = nil,
		[2] = 864
	},
	['Eredath'] = {
		[1] = nil,
		[2] = 882
	},
	['Antoran Wastes'] = {
		[1] = nil,
		[2] = 885
	},
	['Tiragarde Sound'] = {
		[1] = nil,
		[2] = 895
	},
	['Drustvar'] = {
		[1] = nil,
		[2] = 896
	},
	['Stormsong Valley'] = {
		[1] = nil,
		[2] = 942
	},
	['Nazjatar'] = {
		[1] = nil,
		[2] = 1355
	},
	['Mechagon Island'] = {
		[1] = nil,
		[2] = 1462
	},
	['Revendreth'] = {
		[1] = nil,
		[2] = 1525
	},
	['Bastion'] = {
		[1] = nil,
		[2] = 1533
	},
	['Maldraxxus'] = {
		[1] = nil,
		[2] = 1536
	},
	['The Maw'] = {
		[1] = nil,
		[2] = 1543
	},
	['Ardenweald'] = {
		[1] = nil,
		[2] = 1565
	},
	['Korthia'] = {
		[1] = nil,
		[2] = 1961
	},
	['Dragon Isles'] = {
		[1] = nil,
		[2] = 2057
	},
	['City of Threads'] = {
		[1] = nil,
		[2] = 2213
	},
	['The Ringing Deeps'] = {
		[1] = nil,
		[2] = 2214
	},
	['Hallowfall'] = {
		[1] = nil,
		[2] = 2215
	},
	['Isle of Dorn'] = {
		[1] = nil,
		[2] = 2248
	},
	['Azj-Kahet'] = {
		[1] = nil,
		[2] = 2255
	},
	['Zul\'Aman'] = {
		[1] = nil,
		[2] = 2437
	},
	['Harandar'] = {
		[1] = nil,
		[2] = 2413
	},
	['Voidstorm'] = {
		[1] = nil,
		[2] = 2405
	}
}

return D
