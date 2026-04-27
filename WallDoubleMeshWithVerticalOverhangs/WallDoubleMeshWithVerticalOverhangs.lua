function SetStyleParameterStates(parameters)
    local values = parameters:GetParameterValues()

    -- Hide/show the hook length depending on UseHook
    parameters:GetParameter("Overhang", "HookLength"):SetVisible(values.Overhang.UseHook)
end

function rebarRowParameters(group)
    local rebarStyleId = group.RebarStyleId
    local layout = RebarRowEdgeProtectionLayout(group.Step)
    return RebarRowParameters(rebarStyleId, layout)
end

function createOverhangRules(styleParameters, hookAngle)
    local overhangValues = {
        styleParameters.Overhang.TopOverhang1,
        styleParameters.Overhang.TopOverhang2
    }
    
    -- If the user will use a hook
    if styleParameters.Overhang.UseHook then
        local hook = RebarHookParameters(
            math.pi,
            styleParameters.Overhang.HookLength,
            hookAngle
        )
        local overhang = RebarOverhangParameters(overhangValues, hook)
        return {{ObjectSideSelector(WallSide.Top), overhang}}
    else
        -- If the user will not use a hook
        local overhang = RebarOverhangParameters(overhangValues)
        return {{ObjectSideSelector(WallSide.Top), overhang}}
    end
end

function meshParameters(styleParameters)
    local longitudinalParams = rebarRowParameters(styleParameters.LongitudinalRebar)
    
    -- Front mesh (inner, hook rotation angle is 180°)
    local transFront = rebarRowParameters(styleParameters.TransverseRebar)
    transFront.OverhangRules = createOverhangRules(styleParameters, math.pi)
    
    -- Back mesh (outer, hook rotation angle is 0°)
    local transBack = rebarRowParameters(styleParameters.TransverseRebar)
    transBack.OverhangRules = createOverhangRules(styleParameters, 0)
    
    -- Meshes
    local frontMesh = ReinforcingMeshParameters(longitudinalParams, transFront)
    local backMesh = ReinforcingMeshParameters(longitudinalParams, transBack)
    
    -- C-shaped rebar (Length = 1 for auto-tuning)
    local cShaped = CShapedRebarParameters(
        styleParameters.CShapedFixator.RebarStyleId,
        1,
        styleParameters.CShapedFixator.LegLength
    )
    
    -- Rebar mesh supports layout with setting the number of cells passed between the elements
    local layout = ReinforcingMeshSupportsCellLayout(
        styleParameters.CShapedFixator.HorizontalStep,
        styleParameters.CShapedFixator.VerticalStep
    )
    
    -- If the user will use chess order
    if styleParameters.CShapedFixator.UseChessOrder then
        layout.Displacements = {1, 0}
    end
    
    -- Reinforcing mesh supports
    local supports = ReinforcingMeshSupportsParameters(cShaped, layout)
    
    -- Double reinforcing mesh with supports
    local doubleMesh = DoubleReinforcingMeshParameters(frontMesh, backMesh)
    doubleMesh.Supports = supports
    
    return doubleMesh
end

function CreateObjectReinforcement(object, styleParameters)
    -- Clear cover rules
    local clearCoverRules = {
        {ObjectSideSelector(WallSide.Front), styleParameters.ClearCover.ClearCoverInner},
        {ObjectSideSelector(WallSide.Back), styleParameters.ClearCover.ClearCoverOuter},
        {ObjectSideSelector(WallSide.Left), styleParameters.ClearCover.ClearCoverLeft},
        {ObjectSideSelector(WallSide.Right), styleParameters.ClearCover.ClearCoverRight},
        {ObjectSideSelector(WallSide.Top), styleParameters.ClearCover.ClearCoverTop},
        {ObjectSideSelector(WallSide.Bottom), styleParameters.ClearCover.ClearCoverBottom},
        -- For openings (windows and doors)
        {VoidingSelector(ModelObjectType.Window), styleParameters.ClearCover.ClearCoverOpenings},
        {VoidingSelector(ModelObjectType.Door), styleParameters.ClearCover.ClearCoverOpenings}
    }
    
    return CreateDoubleReinforcingMeshInBaseLayer(
        object, 
        clearCoverRules,
        meshParameters(styleParameters)
    )
end
