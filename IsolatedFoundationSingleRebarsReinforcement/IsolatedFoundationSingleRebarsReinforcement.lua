-- Function for controlling the state of parameters in the style dialog.
-- In this example is not required.
function SetStyleParameterStates(parameterContainer)
end

function getRebarDiameter(rebarStyleId)
    local style = GetRebarStyle(rebarStyleId)
    return GetParameterValue(style, "RebarDiameter")
end

function getRebarRadius(rebarStyleId)
    return getRebarDiameter(rebarStyleId) / 2
end

-- The function places rebars along a specified direction.
-- container - the reinforcement container where the bars are added
-- rebarStyleId - the style ID of the rebar
-- curve3d - the rebar curve that will be copied in layout
-- fullLength - the full length of the layout
-- step - the layout step
-- vector - the layout direction
function addRebarLayout(container, rebarStyleId, curve3d, fullLength, step, vector)
    local rebarRadius = getRebarRadius(rebarStyleId)
    local number = math.floor((fullLength - rebarRadius * 2) / step)
    -- the required shift for uniform placement of rebars
    local startShift = (fullLength - step * number) / 2
    curve3d:Shift(vector:Clone():Mul(startShift))
    number = number + 1
    container:AddRebarSet(rebarStyleId, curve3d, vector, step, number)
    return startShift
end

-- The function creates a single horizontal reinforcing mesh at a given level.
-- Longitudinal along the X axis and transverse along the Y axis.
-- Transverse bars are offset vertically by the rebar diameter, to avoid intersections in the same plane.
-- container - the reinforcement container where the bars are added
-- rebarStyleId - the style ID of the rebar
-- halfWidth - the half the mesh width
-- halfDepth - the half the mesh depth
-- level - the mesh level (for longitudinal bars)
-- step - the layout step
function createHorizontalMesh(container, rebarStyleId, halfWidth, halfDepth, level, step)
    local meshDiameter = getRebarDiameter(rebarStyleId)
    
    local longCurve = CreateLineSegment3D(Point3D(-halfWidth, -halfDepth, level), Point3D(-halfWidth, halfDepth, level))
    local xShift = addRebarLayout(container, rebarStyleId, longCurve, halfWidth * 2, step, Vector3D(1, 0, 0))
    
    local transCurve = CreateLineSegment3D(Point3D(-halfWidth, -halfDepth, level + meshDiameter),
        Point3D(halfWidth, -halfDepth, level + meshDiameter))
    local yShift = addRebarLayout(container, rebarStyleId, transCurve, halfDepth * 2, step, Vector3D(0, 1, 0))
    return {xShift = xShift, yShift = yShift}
end

-- The function returns the coordinates of the four corner positions for the vertical bars as a table with four points:
-- left-bottom, left-top, right-bottom, and right-top.
-- halfWidth - the half the foundation width
-- halfDepth - the half the foundation depth
-- offset - the offset from the foundation face
function getCornerPositions(halfWidth, halfDepth, offset)
    return {{
        x = -halfWidth + offset,
        y = -halfDepth + offset
    }, {
        x = -halfWidth + offset,
        y = halfDepth - offset
    }, {
        x = halfWidth - offset,
        y = -halfDepth + offset
    }, {
        x = halfWidth - offset,
        y = halfDepth - offset
    }}
end

-- The function creates vertical rebars: 4 at the corners, the rest uniformly distributed between them.
-- container - Reinforcement container
-- rebarStyleId - the style ID of the rebar
-- halfWidth, halfDepth - the half the working width and depth
-- bottomZ, topZ - Bottom and top elevations (excluding overhangs)
-- overhangLength - Overhang length (the part of the rebar that extends beyond the foundation)
-- count - The number of rebars to create (4, 8, or 12)
-- meshRebarRadius - Mesh rebar radius (for offsetting vertical rebars inward from the mesh edge)
function createVerticalRebars(container, rebarStyleId, halfWidth, halfDepth, bottomZ, topZ, overhangLength, count, meshRebarRadius)
    local verticalRebarRadius = getRebarRadius(rebarStyleId)
    -- consideration of the radius of rebars
    local offset = verticalRebarRadius + meshRebarRadius
    -- the rebar curve that will be used to add rebars
    local curve = CreateLineSegment3D(Point3D(0, 0, bottomZ), Point3D(0, 0, topZ + overhangLength))
    -- corner rebars creation
    local corners = getCornerPositions(halfWidth, halfDepth, offset)
    for _, corner in ipairs(corners) do
        container:AddRebar(rebarStyleId, curve:Clone():Shift(corner.x, corner.y, 0))
    end

    -- if more rebars needed add them between corner rebars
    if count > 4 then
        local perSide = (count - 4) / 4
        -- steps between additional rebars on each side
        local stepX = (halfWidth * 2 - 2 * offset) / (perSide + 1)
        local stepY = (halfDepth * 2 - 2 * offset) / (perSide + 1)

        -- rebars along X
        local yPositions = {-halfDepth + offset, halfDepth - offset}
        for _, y in ipairs(yPositions) do
            for i = 1, perSide do
                local x = -halfWidth + offset + i * stepX
                container:AddRebar(rebarStyleId, curve:Clone():Shift(x, y, 0))
            end
        end

        -- rebars along Y
        local xPositions = {-halfWidth + offset, halfWidth - offset}
        for _, x in ipairs(xPositions) do
            for i = 1, perSide do
                local y = -halfDepth + offset + i * stepY
                container:AddRebar(rebarStyleId, curve:Clone():Shift(x, y, 0))
            end
        end
    end
end

-- The function creates object reinforcement and is called by Renga.
function CreateObjectReinforcement(object, styleParameters)
    local result = ReinforcementContainer()

    -- the example only for rectangular foundation
    if GetParameterValue(object, "IsolatedFoundationShape") == FoundationShape.Trapeze then
        return result
    end

    -- clear covers
    local bottomCover = styleParameters.General.BottomClearCover
    local sideCover = styleParameters.General.SideClearCover
    local topCover = styleParameters.General.TopClearCover

    -- mesh parameters
    local meshRebarId = styleParameters.BottomMesh.RebarStyleId
    local meshStep = styleParameters.BottomMesh.Step

    -- isolated foundation parameters
    local width = GetParameterValue(object, "IsolatedFoundationWidth")
    local depth = GetParameterValue(object, "IsolatedFoundationDepth")
    local height = GetParameterValue(object, "IsolatedFoundationHeight")

    -- modified width and depth according clear cover values
    local halfW = width / 2 - sideCover
    local halfD = depth / 2 - sideCover

    -- bottom mesh rebar radius and diameter
    local meshRebarDiameter = getRebarDiameter(meshRebarId)
    local meshRebarRadius = getRebarRadius(meshRebarId)
    local bottomZ = bottomCover + meshRebarDiameter

    -- create bottom reinforcing mesh
    local shifts = createHorizontalMesh(result, meshRebarId, halfW, halfD, bottomZ, meshStep)

    -- vertical rebars parameters
    local verticalRebarId = styleParameters.VerticalRebars.RebarStyleId
    local verticalOverhang = styleParameters.VerticalRebars.OverhangLength
    local verticalCount = tonumber(styleParameters.VerticalRebars.Count)
    -- vertical rebars positioning values
    local bottomZForVertical = bottomCover + meshRebarDiameter
    local topZForVertical = height - topCover
    halfW = halfW - shifts.xShift
    halfD = halfD - shifts.yShift
    -- create vertical rebars
    createVerticalRebars(result, verticalRebarId, halfW, halfD, bottomZForVertical, topZForVertical,
        verticalOverhang, verticalCount, meshRebarRadius)

    return result
end