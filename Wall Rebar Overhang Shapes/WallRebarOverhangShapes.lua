-- WallRebarOverhangShapes.lua
-- Demonstrates rebar overhang shapes with configurable bend angle and anchor hooks
-- Features:
-- - Double reinforcing mesh with horizontal and vertical rebars
-- - Top overhangs with configurable length
-- - Optional 90° bend at the top with configurable horizontal length using RebarOverhangShape
-- - Optional anchor hooks on overhangs (with or without bend) with configurable angle, length and rotation
-- - Different hook rotations for outer and inner vertical rebars
-- - C-shaped fixators in chess order
function SetStyleParameterStates(parameters)
    local values = parameters:GetParameterValues()

    -- Outer vertical rebar bend and hook visibility
    local outerUseBend = values.OuterVerticalRebar.UseBend
    parameters:GetParameter("OuterVerticalRebar", "BendAngle"):SetVisible(outerUseBend)
    parameters:GetParameter("OuterVerticalRebar", "BendLength"):SetVisible(outerUseBend)

    local outerUseHook = values.OuterVerticalRebar.UseHook
    parameters:GetParameter("OuterVerticalRebar", "HookAngle"):SetVisible(outerUseHook)
    parameters:GetParameter("OuterVerticalRebar", "HookLength"):SetVisible(outerUseHook)
    parameters:GetParameter("OuterVerticalRebar", "HookRotation"):SetVisible(outerUseHook)

    -- Inner vertical rebar bend and hook visibility
    local innerUseBend = values.InnerVerticalRebar.UseBend
    parameters:GetParameter("InnerVerticalRebar", "BendAngle"):SetVisible(innerUseBend)
    parameters:GetParameter("InnerVerticalRebar", "BendLength"):SetVisible(innerUseBend)

    local innerUseHook = values.InnerVerticalRebar.UseHook
    parameters:GetParameter("InnerVerticalRebar", "HookAngle"):SetVisible(innerUseHook)
    parameters:GetParameter("InnerVerticalRebar", "HookLength"):SetVisible(innerUseHook)
    parameters:GetParameter("InnerVerticalRebar", "HookRotation"):SetVisible(innerUseHook)
end

-- Creates rebar row parameters for horizontal rebar (without overhangs)
-- @param group: Parameter group containing RebarStyleId and Step
-- @return RebarRowParameters
function createHorizontalRow(group)
    local rebarStyleId = group.RebarStyleId
    local layout = RebarRowEdgeProtectionLayout(group.Step)
    local row = RebarRowParameters(rebarStyleId, layout)
    row.BendingFactor = 1.25
    return row
end

-- Creates rebar row parameters for vertical rebar (with shared step)
-- @param verticalGroup: Parameter group containing Step
-- @param layerGroup: Parameter group containing RebarStyleId and overhang settings
-- @return RebarRowParameters
function createVerticalRow(verticalGroup, layerGroup)
    local rebarStyleId = verticalGroup.RebarStyleId
    local layout = RebarRowEdgeProtectionLayout(verticalGroup.Step)
    local row = RebarRowParameters(rebarStyleId, layout)
    row.BendingFactor = 1.25

    local overhangLength = layerGroup.TopOverhang
    local useBend = layerGroup.UseBend
    local useHook = layerGroup.UseHook

    -- Create overhang parameters
    local overhangParams

    if useBend then
        -- With bend: use shape for horizontal part
        local bendAngle = layerGroup.BendAngle
        local bendLength = layerGroup.BendLength
        local bendAngleRad = math.rad(bendAngle)
        local segments = {RebarBendingSegment(math.pi / 2, bendLength)}
        local overhangShape = RebarOverhangShape(segments, bendAngleRad)

        if useHook then
            -- Shape + hook
            local hookBendAngle = math.rad(layerGroup.HookAngle)
            local hookRotation = math.rad(layerGroup.HookRotation)
            local hook = RebarHookParameters(hookBendAngle, layerGroup.HookLength, hookRotation)
            overhangParams = RebarOverhangParameters({overhangLength}, {overhangShape}, hook)
        else
            -- Only shape, no hook
            overhangParams = RebarOverhangParameters({overhangLength}, {overhangShape})
        end
    else
        -- Without bend: simple overhang
        if useHook then
            -- Simple overhang with hook
            local hookBendAngle = math.rad(layerGroup.HookAngle)
            local hookRotation = math.rad(layerGroup.HookRotation)
            local hook = RebarHookParameters(hookBendAngle, layerGroup.HookLength, hookRotation)
            overhangParams = RebarOverhangParameters({overhangLength}, hook)
        else
            -- Simple overhang without hook
            overhangParams = RebarOverhangParameters({overhangLength})
        end
    end

    -- Apply overhang rule for top side
    row.OverhangRules = {{ObjectSideSelector(WallSide.Top), overhangParams}}

    return row
end

-- Creates double reinforcing mesh with overhang shapes
-- @param styleParameters: Style parameters
-- @return DoubleReinforcingMeshParameters
function meshParameters(styleParameters)
    -- Horizontal rebar (constant step, no overhangs)
    local horizontalParams = createHorizontalRow(styleParameters.HorizontalRebar)

    -- Vertical rebar - outer layer with top overhang
    local outerVerticalParams = createVerticalRow(styleParameters.VerticalRebar, styleParameters.OuterVerticalRebar)

    -- Vertical rebar - inner layer with top overhang
    local innerVerticalParams = createVerticalRow(styleParameters.VerticalRebar, styleParameters.InnerVerticalRebar)

    -- Front mesh (inner side): vertical in front of horizontal
    local frontMesh = ReinforcingMeshParameters(horizontalParams, innerVerticalParams)
    frontMesh.RowsOrder = ReinforcingMeshRowsOrder.TransverseInFront

    -- Back mesh (outer side): horizontal in front of vertical (default)
    local backMesh = ReinforcingMeshParameters(horizontalParams, outerVerticalParams)

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
    local cShaped = CShapedRebarParameters(params.RebarStyleId, 1, params.LegLength)
    cShaped.BendingFactor = 1.25

    -- Layout with cell-based spacing
    local layout = ReinforcingMeshSupportsCellLayout(params.HorizontalStep, params.VerticalStep)

    -- Chess order pattern: offset alternating rows
    if params.UseChessOrder then
        layout.Displacements = {1, 0}
    end

    return ReinforcingMeshSupportsParameters(cShaped, layout)
end

-- Main reinforcement creation function
-- @param object: Wall entity to reinforce
-- @param styleParameters: User-defined style parameters
-- @return ReinforcementContainer
function CreateObjectReinforcement(object, styleParameters)
    -- Define clear cover rules for all faces and openings
    local clearCoverRules = {{ObjectSideSelector(WallSide.Front), styleParameters.ClearCover.Inner},
                             {ObjectSideSelector(WallSide.Back), styleParameters.ClearCover.Outer},
                             {ObjectSideSelector(WallSide.Top), styleParameters.ClearCover.Top},
                             {ObjectSideSelector(WallSide.Bottom), styleParameters.ClearCover.Bottom},
                             {ObjectSideSelector(WallSide.Left), styleParameters.ClearCover.Left},
                             {ObjectSideSelector(WallSide.Right), styleParameters.ClearCover.Right},
                             {VoidingSelector(ModelObjectType.Window), styleParameters.ClearCover.Openings},
                             {VoidingSelector(ModelObjectType.Door), styleParameters.ClearCover.Openings}}

    -- Create double reinforcing mesh
    local meshParams = meshParameters(styleParameters)

    return CreateDoubleReinforcingMeshInBaseLayer(object, clearCoverRules, meshParams)
end
