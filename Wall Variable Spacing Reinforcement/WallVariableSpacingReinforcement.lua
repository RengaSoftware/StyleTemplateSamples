-- WallVariableSpacingReinforcement.lua
-- Demonstrates variable spacing of vertical rebar within a row using ZonedRebarRowParameters
-- Features:
-- - Three zones: start zone, main zone, end zone with different spacing for vertical rebar
-- - Individual top overhang lengths for each zone
-- - Horizontal rebar with constant spacing
-- - C-shaped fixators in chess order

function SetStyleParameterStates(parameters)
    -- No dynamic visibility changes in this minimal example
    -- All groups are always visible
end

-- Creates rebar row parameters with edge protection layout and top overhang
-- @param group: Parameter group containing RebarStyleId, Step, TopOverhang
-- @return RebarRowParameters
function rebarRowParametersWithTopOverhang(group)
    local rebarStyleId = group.RebarStyleId
    local layout = RebarRowEdgeProtectionLayout(group.Step)
    local row = RebarRowParameters(rebarStyleId, layout)
    
    -- Define overhang rules only for top side
    local overhangValues = { group.TopOverhang }
    local overhang = RebarOverhangParameters(overhangValues)
    row.OverhangRules = {
        { ObjectSideSelector(WallSide.Top), overhang }
    }
    
    return row
end

-- Creates rebar row parameters without overhangs (for horizontal rebar)
-- @param group: Parameter group containing RebarStyleId and Step
-- @return RebarRowParameters
function rebarRowParameters(group)
    local rebarStyleId = group.RebarStyleId
    local layout = RebarRowEdgeProtectionLayout(group.Step)
    return RebarRowParameters(rebarStyleId, layout)
end

-- Creates ZonedRebarRowParameters for vertical reinforcement
-- @param styleParameters: Style parameters containing start, main and end zone settings
-- @return ZonedRebarRowParameters
function createZonedVerticalRow(styleParameters)
    local startParams = styleParameters.StartZone
    local mainParams = styleParameters.MainZone
    local endParams = styleParameters.EndZone
    
    -- Create row parameters for each zone (only top overhang)
    local startRow = rebarRowParametersWithTopOverhang(startParams)
    local mainRow = rebarRowParametersWithTopOverhang(mainParams)
    local endRow = rebarRowParametersWithTopOverhang(endParams)
    
    -- Create zoned row with main zone as base
    local zonedRow = ZonedRebarRowParameters(mainRow)
    
    -- Add start zone as a table of {row, size}
    zonedRow.StartZones = { { startRow, startParams.ZoneSize } }
    
    -- Add end zone as a table of {row, size}
    zonedRow.EndZones = { { endRow, endParams.ZoneSize } }
    
    -- Set minimum clearance between zones (default is 25 mm)
    zonedRow.MinClearance = 25
    
    return zonedRow
end

-- Creates double reinforcing mesh with variable spacing vertical rebar
-- @param styleParameters: Style parameters
-- @return DoubleReinforcingMeshParameters
function meshParameters(styleParameters)
    -- Horizontal rebar with constant spacing (LongitudinalRow)
    local horizontalParams = rebarRowParameters(styleParameters.HorizontalRebar)
    
    -- Vertical rebar with variable spacing (TransverseRow)
    local verticalParams = createZonedVerticalRow(styleParameters)
    
    -- Front mesh: vertical in front of horizontal
    -- Note: For wall, TransverseRow (vertical) is set in front
    local frontMesh = ReinforcingMeshParameters(horizontalParams, verticalParams)
    frontMesh.RowsOrder = ReinforcingMeshRowsOrder.TransverseInFront
    
    -- Back mesh: horizontal in front of vertical (default)
    local backMesh = ReinforcingMeshParameters(horizontalParams, verticalParams)
    
    local doubleMesh = DoubleReinforcingMeshParameters(frontMesh, backMesh)
    
    -- Add C-shaped fixators
    doubleMesh.Supports = createSupports(styleParameters)
    
    return doubleMesh
end

-- Creates C-shaped fixators for mesh spacing
-- @param styleParameters: Style parameters containing fixator settings
-- @return ReinforcingMeshSupportsParameters
function createSupports(styleParameters)
    local params = styleParameters.CShapedFixators
    
    -- Create C-shaped rebar fixator
    -- Length = 1 for auto-tuning
    local cShaped = CShapedRebarParameters(
        params.RebarStyleId,
        1,
        params.LegLength
    )
    cShaped.BendingFactor = 1.25
    
    -- Layout with cell-based spacing
    local layout = ReinforcingMeshSupportsCellLayout(
        params.HorizontalStep,
        params.VerticalStep
    )
    
    -- Chess order pattern: offset alternating rows
    if params.UseChessOrder then
        layout.Displacements = { 1, 0 }
    end
    
    return ReinforcingMeshSupportsParameters(cShaped, layout)
end

-- Main reinforcement creation function
-- @param object: Wall entity to reinforce
-- @param styleParameters: User-defined style parameters
-- @return ReinforcementContainer
function CreateObjectReinforcement(object, styleParameters)
    -- Define clear cover rules for all faces and openings
    local clearCoverRules = {
        { ObjectSideSelector(WallSide.Front), styleParameters.ClearCover.Inner },
        { ObjectSideSelector(WallSide.Back), styleParameters.ClearCover.Outer },
        { ObjectSideSelector(WallSide.Top), styleParameters.ClearCover.Top },
        { ObjectSideSelector(WallSide.Bottom), styleParameters.ClearCover.Bottom },
        { ObjectSideSelector(WallSide.Left), styleParameters.ClearCover.Left },
        { ObjectSideSelector(WallSide.Right), styleParameters.ClearCover.Right },
        { VoidingSelector(ModelObjectType.Window), styleParameters.ClearCover.Openings },
        { VoidingSelector(ModelObjectType.Door), styleParameters.ClearCover.Openings }
    }
    
    -- Create double reinforcing mesh
    local meshParams = meshParameters(styleParameters)
    
    return CreateDoubleReinforcingMeshInBaseLayer(object, clearCoverRules, meshParams)
end