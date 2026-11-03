-- Minimal example: alternating reinforcement units in a row along the wall.

function SetStyleParameterStates(parameters)
    -- Nothing to toggle in the minimal example.
end

-- Returns the rotation matrix for the reinforcement unit coordinate system.
function getUnitTransform()
    return Matrix3D():Rotate(
        Axis3D(Point3D(0, 0, 0), Vector3D(1, 0, 0)),
        -math.pi / 2
    )
end

-- Returns the clear cover rules for the wall.
function getClearCoverRules(styleParameters)
    return {
        { ObjectSideSelector(WallSide.Bottom), 0 },
        { AnyFaceSelector(), styleParameters.General.ClearCover }
    }
end

-- Creates an alternating row of reinforcement units.
function createAlternatingRow(evenUnitId, oddUnitId, step, displacement)
    local units = {
        { evenUnitId, getUnitTransform() },
        { oddUnitId,  getUnitTransform() }
    }

    local unitOffsets = { 0, 0 }

    local layout = ReinforcementUnitUniformLayout(step, displacement)

    local row = ReinforcementAlternatingUnitRowParameters(units, unitOffsets, layout)
    row.FacesToIgnore = { ObjectSideSelector(WallSide.Top) }

    return row
end

-- The function creates object reinforcement and is called by Renga.
function CreateObjectReinforcement(object, styleParameters)
    -- Alternating reinforcement units parameters
    local evenUnitId   = styleParameters.AlternatingUnits.EvenUnitId
    local oddUnitId    = styleParameters.AlternatingUnits.OddUnitId
    local step         = styleParameters.AlternatingUnits.Step
    local displacement = styleParameters.AlternatingUnits.Displacement

    -- Create alternating row
    local row = createAlternatingRow(evenUnitId, oddUnitId, step, displacement)

    -- Wrap the row into a section
    local rowInSection = ReinforcementUnitRowInSectionParameters(row, Placement2DAxis.AxisX)

    -- Create and return reinforcement units in the base layer of the wall directly
    return CreateReinforcementUnitsInBaseLayer(
        object,
        getClearCoverRules(styleParameters),
        rowInSection
    )
end