function SetStyleParameterStates(parameters)
    local values = parameters:GetParameterValues()

    -- Visibility of the edge reinforcement parameters
    local useEdgeReinforcement = values.General.UseEdgeReinforcement
    parameters:GetParameterGroup("EdgeReinforcement"):SetVisible(useEdgeReinforcement)

    -- Visibility of the supports
    local useMeshSupports = values.General.UseMeshSupports
    parameters:GetParameterGroup("MeshSupports"):SetVisible(useMeshSupports)
end

function rebarRowParameters(group)
    -- Rebar row parameters: rebar style + edge protection layout
    local rebarStyleId = group.RebarStyleId
    local layout = RebarRowEdgeProtectionLayout(group.Step)
    return RebarRowParameters(rebarStyleId, layout)
end

function meshParameters(styleParameters)
    -- Double mesh parameters
    local longitudinalParams = rebarRowParameters(styleParameters.LongitudinalRebar)
    local transverseParams = rebarRowParameters(styleParameters.TransverseRebar)

    local frontMesh = ReinforcingMeshParameters(longitudinalParams, transverseParams)
    local backMesh = ReinforcingMeshParameters(longitudinalParams, transverseParams)

    return DoubleReinforcingMeshParameters(frontMesh, backMesh)
end

function createSupports(styleParameters)
    -- Rebar chair parameters: rebar style, base length, leg length, height (1 = auto)
    local chairParams = RebarChairParameters(styleParameters.MeshSupports.SupportsRebarStyleId,
        styleParameters.MeshSupports.BaseLength, styleParameters.MeshSupports.LegLength, 1)

    -- Rebar mesh supports layout with setting the distance between elements
    local supportsLayout = ReinforcingMeshSupportsDistanceLayout(styleParameters.MeshSupports.HorizontalStep,
        styleParameters.MeshSupports.VerticalStep)

    -- Rebar mesh supports layout with setting the number of cells passed between the elements
    if styleParameters.MeshSupports.UseChessOrder then
        supportsLayout.Displacements = {0, styleParameters.MeshSupports.HorizontalStep / 2}
    end

    return ReinforcingMeshSupportsParameters(chairParams, supportsLayout)
end

function createEdgeReinforcement(styleParameters)
    -- U-shaped edge reinforcement: style, edge reinforcement step, leg length
    local layout = EdgeReinforcementCenteredLayout(styleParameters.EdgeReinforcement.EdgeStep)
    local selectors = {ObjectSideSelector(FloorSide.Side)}
    -- Length = 1 for auto-tuning
    local uShaped = UShapedRebarParameters(styleParameters.EdgeReinforcement.EdgeRebarStyleId, 1,
        styleParameters.EdgeReinforcement.LeftLegLength, styleParameters.EdgeReinforcement.RightLegLength)
    return EdgeReinforcementParameters(uShaped, layout, selectors)
end

function CreateObjectReinforcement(object, styleParameters)
    local meshParams = meshParameters(styleParameters)

    -- Creating supports
    if styleParameters.MeshSupports.UseMeshSupports then
        meshParams.Supports = createSupports(styleParameters)
    end

    -- Creating edge reinforcement
    if styleParameters.EdgeReinforcement.UseEdgeReinforcement then
        return CreateDoubleReinforcingMeshInBaseLayer(object, {}, meshParams, createEdgeReinforcement(styleParameters))
    end

    -- Creating double reinforcing mesh
    return CreateDoubleReinforcingMeshInBaseLayer(object, {}, meshParams)
end
