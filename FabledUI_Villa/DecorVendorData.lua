local Villa = _G.FabledUI_Villa
-- Lazy: the backing data lives in the LoadOnDemand catalog shard, so capturing
-- the provider table here would capture an empty one. See Villa:MakeProviderProxy.
local module = Villa:MakeProviderProxy("decorvendor")
Villa.DecorVendorData = module
Villa:RegisterModule("DecorVendorData", module)
