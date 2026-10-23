-- FloorUShapedRebarsWithHooks.lua
-- Demonstrates U-shaped edge reinforcement rebars with configurable left/right anchor hooks
-- Features:
-- - Double reinforcing mesh with adjustable spacing
-- - U-shaped edge reinforcement with separate leg lengths
-- - Left and right anchor hooks with configurable angle, extension, and rotation
-- - Optional mesh supports
function SetStyleParameterStates(parameters)
    local values = parameters:GetParameterValues()

    -- Edge reinforcement visibility
    local useEdgeReinforcement = values.General.UseEdgeReinforcement
    parameters:GetParameterGroup("EdgeReinforcement"):SetVisible(useEdgeReinforcement)
    if useEdgeReinforcement then
        -- Left hook parameters visibility (top hook)
        local useLeftHook = values.EdgeReinforcement.UseLeftHook
        parameters:GetParameter("EdgeReinforcement", "LeftHookAngle"):SetVisible(useLeftHook)
        parameters:GetParameter("EdgeReinforcement", "LeftHookLength"):SetVisible(useLeftHook)
        parameters:GetParameter("EdgeReinforcement", "LeftHookRotation"):SetVisible(useLeftHook)

        -- Right hook parameters visibility (bottom hook)
        local useRightHook = values.EdgeReinforcement.UseRightHook
        parameters:GetParameter("EdgeReinforcement", "RightHookAngle"):SetVisible(useRightHook)
        parameters:GetParameter("EdgeReinforcement", "RightHookLength"):SetVisible(useRightHook)
        parameters:GetParameter("EdgeReinforcement", "RightHookRotation"):SetVisible(useRightHook)
    end

    -- Mesh supports visibility
    local useMeshSupports = values.General.UseMeshSupports
    parameters:GetParameterGroup("MeshSupports"):SetVisible(useMeshSupports)
end

-- Creates rebar row parameters with edge protection layout
-- @param group: Parameter group containing RebarStyleId and Step
-- @return RebarRowParameters
function rebarRowParameters(group)
    local rebarStyleId = group.RebarStyleId
    local layout = RebarRowEdgeProtectionLayout(group.Step)
    return RebarRowParameters(rebarStyleId, layout)
end

-- Creates double reinforcing mesh parameters
-- @param styleParameters: Style parameters containing longitudinal and transverse rebar settings
-- @return DoubleReinforcingMeshParameters
function meshParameters(styleParameters)
    local longitudinalParams = rebarRowParameters(styleParameters.LongitudinalRebar)
    local transverseParams = rebarRowParameters(styleParameters.TransverseRebar)

    local frontMesh = ReinforcingMeshParameters(longitudinalParams, transverseParams)
    local backMesh = ReinforcingMeshParameters(longitudinalParams, transverseParams)

    return DoubleReinforcingMeshParameters(frontMesh, backMesh)
end

-- Creates U-shaped edge reinforcement with anchor hooks
-- @param styleParameters: Style parameters containing edge reinforcement settings
-- @return EdgeReinforcementParameters
function createEdgeReinforcement(styleParameters)
    if not styleParameters.General.UseEdgeReinforcement then
        return nil
    end

    local params = styleParameters.EdgeReinforcement

    -- Create U-shaped rebar with automatic base length (1 = auto-tune)
    -- Base length auto-adapts to floor thickness minus clear cover
    local uShaped = UShapedRebarParameters(params.RebarStyleId, 1, -- BaseLength (auto)
    params.LeftLegLength, params.RightLegLength)

    -- Apply bend radius factor for U-shaped rebar
    uShaped.BendingFactor = params.BendingFactor

    -- Configure left anchor hook (top hook) if enabled
    if params.UseLeftHook then
        local bendAngle = math.rad(params.LeftHookAngle)
        local rotationAngle = math.rad(params.LeftHookRotation)
        uShaped.LeftHook = RebarHookParameters(bendAngle, params.LeftHookLength, rotationAngle)
    end

    -- Configure right anchor hook (bottom hook) if enabled
    if params.UseRightHook then
        local bendAngle = math.rad(params.RightHookAngle)
        local rotationAngle = math.rad(params.RightHookRotation)
        uShaped.RightHook = RebarHookParameters(bendAngle, params.RightHookLength, rotationAngle)
    end

    -- Edge reinforcement layout: centered along the edge with specified step
    local layout = EdgeReinforcementCenteredLayout(params.Step)

    -- Apply to all side faces of the floor slab
    local selectors = {ObjectSideSelector(FloorSide.Side)}

    return EdgeReinforcementParameters(uShaped, layout, selectors)
end

-- Creates mesh supports (rebar chairs)
-- @param styleParameters: Style parameters containing mesh support settings
-- @return ReinforcingMeshSupportsParameters
function createSupports(styleParameters)
    local params = styleParameters.MeshSupports

    -- Create C-shaped rebar chair with automatic height (1 = auto-tune)
    local chairParams =
        RebarChairParameters(params.RebarStyleId, params.BaseLength, params.LegLength, 1 -- Height (auto)
        )

    -- Apply bend radius factor
    chairParams.BendingFactor = params.BendingFactor

    -- Layout with distance-based spacing
    local supportsLayout = ReinforcingMeshSupportsDistanceLayout(params.HorizontalStep, params.VerticalStep)

    -- Chess order pattern: offset alternating rows
    if params.UseChessOrder then
        supportsLayout.Displacements = {0, params.HorizontalStep / 2}
    end

    return ReinforcingMeshSupportsParameters(chairParams, supportsLayout)
end

-- Main reinforcement creation function
-- @param object: Floor slab entity to reinforce
-- @param styleParameters: User-defined style parameters
-- @return ReinforcementContainer
function CreateObjectReinforcement(object, styleParameters)
    -- Define clear cover rules for top, bottom, and side faces
    local clearCoverRules = {{ObjectSideSelector(FloorSide.Top), styleParameters.ClearCover.Top},
                             {ObjectSideSelector(FloorSide.Bottom), styleParameters.ClearCover.Bottom},
                             {ObjectSideSelector(FloorSide.Side), styleParameters.ClearCover.Side}}

    -- Create the double reinforcing mesh
    local meshParams = meshParameters(styleParameters)

    -- Add mesh supports if enabled
    if styleParameters.General.UseMeshSupports then
        meshParams.Supports = createSupports(styleParameters)
    end

    -- Create only the double reinforcing mesh without edge reinforcement
    return CreateDoubleReinforcingMeshInBaseLayer(object, clearCoverRules, meshParams, createEdgeReinforcement(styleParameters))
end
