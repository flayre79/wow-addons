local T = FabledUI_UIToolkit
T.ScrollBox = {}

--- SVC-005: ScrollBox Adapter
--- Wraps the verbose 10.0+ ScrollBox and DataProvider creation into a single safe call.
--- @param parent frame The parent frame
--- @param template string The XML template for the rows
--- @param initializer function Function to initialize each row: function(frame, elementData)
function T.ScrollBox:Create(parent, template, initializer)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    -- ScrollBox
    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 0, 0)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 0)

    -- ScrollBar
    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 5, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 5, 0)

    -- View & DataProvider
    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer(template, initializer)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    
    local dataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(dataProvider)

    -- Return the container, dataProvider, and scrollBox for easy list updates
    return container, dataProvider, scrollBox
end
