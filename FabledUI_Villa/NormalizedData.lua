local Villa = _G.FabledUI_Villa
-- Lazy: NormalizedData normalizes across the bulk catalog providers, so it
-- ships in the same LoadOnDemand shard they do.
local module = Villa:MakeProviderProxy("normalized")
Villa.NormalizedData = module
Villa:RegisterModule("NormalizedData", module)
