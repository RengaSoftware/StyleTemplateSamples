-- Function for controlling the state of parameters in the style dialog.
function SetStyleParameterStates(parameters)
    local values = parameters:GetParameterValues()

    local hasTopOverhang = values.LongitudinalRebars.TopOverhangEnabled

    parameters:GetParameter("LongitudinalRebars", "TopOverhang"):SetVisible(hasTopOverhang)
    parameters:GetParameter("General", "TopClearCover"):SetVisible(not hasTopOverhang)
end

function getRebarRadius(rebarStyleId)
    local style = GetRebarStyle(rebarStyleId)
    return GetParameterValue(style, "RebarDiameter") / 2
end

-- Returns the offset of the transverse rebar from the side face.
function getTransverseRebarOffset(sideClearCover, transverseFreeEnd, transverseRebarRadius)
    return sideClearCover + transverseFreeEnd + transverseRebarRadius
end

-- Returns the offset of the longitudinal rebar from the side face.
function getLongitudinalRebarOffset(sideClearCover, transverseFreeEnd,
                                    transverseRebarDiameter, longitudinalRebarRadius)
    return sideClearCover + transverseFreeEnd + transverseRebarDiameter + longitudinalRebarRadius
end

-- Returns the coordinates of the four corner positions for the longitudinal bars
-- as a table with four points: left-bottom, left-top, right-bottom, right-top.
function getCornerPositions(halfWidth, halfDepth, offset)
    return {
        { x = -halfWidth + offset, y = -halfDepth + offset },
        { x = -halfWidth + offset, y =  halfDepth - offset },
        { x =  halfWidth - offset, y = -halfDepth + offset },
        { x =  halfWidth - offset, y =  halfDepth - offset }
    }
end

-- The function creates longitudinal rebars at the four corners of the column section.
function createLongitudinalRebars(container, rebarStyleId,
                                  halfWidth, halfDepth,
                                  offset,
                                  bottomZ, topZ)
    local curve = CreateLineSegment3D(Point3D(0, 0, bottomZ), Point3D(0, 0, topZ))

    local corners = getCornerPositions(halfWidth, halfDepth, offset)
    for _, corner in ipairs(corners) do
        container:AddRebar(rebarStyleId, curve:Clone():Shift(corner.x, corner.y, 0))
    end
end

-- The function creates transverse rebars along the X and Y axes,
-- laid out along the column height as rebar sets with the specified step.
function createTransverseRebars(container, rebarStyleId,
                                halfWidth, halfDepth,
                                sideCover,
                                transverseHalfWidth, transverseHalfDepth,
                                firstZAlongX, firstZAlongY,
                                lastZ, step)
    local xStart = -halfWidth + sideCover
    local xEnd   =  halfWidth - sideCover
    local yStart = -halfDepth + sideCover
    local yEnd   =  halfDepth - sideCover

    -- Rebars along X, laid out along Z via RebarSet
    if firstZAlongX <= lastZ then
        local countX = math.floor((lastZ - firstZAlongX) / step) + 1
        if countX > 0 then
            local curveX1 = CreateLineSegment3D(Point3D(xStart, -transverseHalfDepth, firstZAlongX), Point3D(xEnd, -transverseHalfDepth, firstZAlongX))
            local curveX2 = CreateLineSegment3D(Point3D(xStart,  transverseHalfDepth, firstZAlongX), Point3D(xEnd,  transverseHalfDepth, firstZAlongX))
            container:AddRebarSet(rebarStyleId, curveX1, Vector3D(0, 0, 1), step, countX)
            container:AddRebarSet(rebarStyleId, curveX2, Vector3D(0, 0, 1), step, countX)
        end
    end

    -- Rebars along Y, laid out along Z via RebarSet
    if firstZAlongY <= lastZ then
        local countY = math.floor((lastZ - firstZAlongY) / step) + 1
        if countY > 0 then
            local curveY1 = CreateLineSegment3D(Point3D(-transverseHalfWidth, yStart, firstZAlongY), Point3D(-transverseHalfWidth, yEnd, firstZAlongY))
            local curveY2 = CreateLineSegment3D(Point3D( transverseHalfWidth, yStart, firstZAlongY), Point3D( transverseHalfWidth, yEnd, firstZAlongY))
            container:AddRebarSet(rebarStyleId, curveY1, Vector3D(0, 0, 1), step, countY)
            container:AddRebarSet(rebarStyleId, curveY2, Vector3D(0, 0, 1), step, countY)
        end
    end
end

-- The function creates object reinforcement and is called by Renga.
function CreateObjectReinforcement(object, styleParameters)
    local result = ReinforcementContainer()

    -- the example only for rectangular column profile
    local profile = GetSectionProfile(object)
    if GetTypeName(profile) ~= "RectangularProfile" then
        return result
    end

    -- clear covers
    local bottomCover = styleParameters.General.BottomClearCover
    local sideCover   = styleParameters.General.SideClearCover
    local topCover    = styleParameters.General.TopClearCover

    -- longitudinal rebars parameters
    local longitudinalRebarId  = styleParameters.LongitudinalRebars.RebarStyleId
    local longitudinalFreeEnd  = styleParameters.LongitudinalRebars.FreeEnd
    local topOverhangEnabled   = styleParameters.LongitudinalRebars.TopOverhangEnabled
    local topOverhang          = styleParameters.LongitudinalRebars.TopOverhang

    -- transverse rebars parameters
    local transverseRebarId   = styleParameters.TransverseRebars.RebarStyleId
    local transverseFreeEnd   = styleParameters.TransverseRebars.FreeEnd
    local transverseStep      = styleParameters.TransverseRebars.Step

    -- rebar radius
    local longitudinalRebarRadius = getRebarRadius(longitudinalRebarId)
    local transverseRebarRadius   = getRebarRadius(transverseRebarId)
    local transverseRebarDiameter = transverseRebarRadius * 2

    -- column parameters
    local columnHeight = GetParameterValue(object, "ColumnHeight")

    -- modified width and depth according clear cover values
    local halfWidth = profile.Width / 2
    local halfDepth = profile.Height / 2

    -- longitudinal rebars offset from the column face
    local longitudinalOffset = getLongitudinalRebarOffset(
        sideCover, transverseFreeEnd, transverseRebarDiameter, longitudinalRebarRadius)
        
    local minDistanceBetweenLongitudinalCenter = longitudinalRebarRadius * 2
    if (profile.Width - longitudinalOffset * 2) < minDistanceBetweenLongitudinalCenter or 
       (profile.Height - longitudinalOffset * 2) < minDistanceBetweenLongitudinalCenter then
        return result
    end

    -- longitudinal rebars elevations
    local bottomZ = bottomCover
    local topZ    = columnHeight
    if topOverhangEnabled then
        topZ = topZ + topOverhang
    else
        topZ = topZ - topCover
    end

    if topZ <= bottomZ then
        return result
    end

    -- create longitudinal rebars
    createLongitudinalRebars(result, longitudinalRebarId,
                             halfWidth, halfDepth,
                             longitudinalOffset,
                             bottomZ, topZ)

    -- transverse rebars parameters
    local transverseOffset = getTransverseRebarOffset(sideCover, transverseFreeEnd, transverseRebarRadius)

    local transverseHalfWidth = halfWidth - transverseOffset
    local transverseHalfDepth = halfDepth - transverseOffset

    if transverseHalfWidth <= 0 or transverseHalfDepth <= 0 then
        return result
    end

    -- initial elevations for X and Y rebars
    local firstZAlongX = bottomCover + longitudinalFreeEnd + transverseRebarRadius
    local firstZAlongY = bottomCover + longitudinalFreeEnd + transverseRebarRadius * 3

    -- upper bound of the layout (transverse rebars do not go into the overhang)
    local lastZ = columnHeight - longitudinalFreeEnd - transverseRebarRadius
    if not topOverhangEnabled then
        lastZ = lastZ - topCover
    end

    if lastZ <= firstZAlongX or lastZ <= firstZAlongY then
        return result
    end

    -- create transverse rebars
    createTransverseRebars(result, transverseRebarId,
                           halfWidth, halfDepth,
                           sideCover,
                           transverseHalfWidth, transverseHalfDepth,
                           firstZAlongX, firstZAlongY,
                           lastZ, transverseStep)

    return result
end