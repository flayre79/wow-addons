local Villa = _G.FabledUI_Villa
local module = (Villa and Villa.GetProviderStore and Villa:GetProviderStore("home")) or {}
Villa.HomeData = module
Villa:RegisterModule("HomeData", module)

