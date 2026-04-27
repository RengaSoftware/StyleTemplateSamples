-- Get the parameters of the current style.
local parameters = Style.GetParameterValues()

local length = parameters.Dimensions.Length
local width = parameters.Dimensions.Width
local longRebarStyleID = parameters.LongitudinalReinforcement.RebarStyleId
local longFreeEnd = parameters.LongitudinalReinforcement.FreeEnd
local longStep = parameters.LongitudinalReinforcement.Step
local transRebarStyleID = parameters.TransverseReinforcement.RebarStyleId
local transFreeEnd = parameters.TransverseReinforcement.FreeEnd
local transStep = parameters.TransverseReinforcement.Step

-- Vector shift function
function ShiftedByVector(object, vector, length)
    return object:Shift(vector:GetX() * length, vector:GetY() * length, vector:GetZ() * length)
end

-- The function of getting the rebar radius by ID
function GetRebarRadius(rebarStyleId)
    local style = GetRebarStyle(rebarStyleId)
    return GetParameterValue(style, "RebarDiameter") / 2
end

-- Function of laying the rebars with free ends and a finishing step on one side
function CreateRebarLayoutWithFreeEnd(rebarStyleId, curve3d, fullLength, freeEnd, step, vector)
    local rebarRadius = GetRebarRadius(rebarStyleId)
    local length = fullLength - freeEnd * 2 - rebarRadius * 2
    local number = math.floor(length / step)
    local lastStep = length - step * number
    if lastStep < rebarRadius * 2 and lastStep ~= 0 then
        number = number - 1
    end
    ShiftedByVector(curve3d, vector, freeEnd + rebarRadius)
    Style.AddRebarSet(rebarStyleId, curve3d, vector, step, number + 1)
    if lastStep ~= 0 then
        ShiftedByVector(curve3d, vector, length)
        Style.AddRebar(rebarStyleId, curve3d)
    end
end

-- Function creates a symbolic representation of the Reinforcement unit for display on drawings.
function MakeSymbolicGeometrySet()
    local rectangle = CreateRectangle2D(Point2D(0, 0), 0, length, width)
    local line = CreateLineSegment2D(Point2D(-length / 2, -width / 2), Point2D(length / 2, width / 2))
    local geometrySet = GeometrySet2D()
    geometrySet:AddCurve(rectangle)
    geometrySet:AddCurve(line)
    return geometrySet
end

-- Height of placement of longitudinal rebars
local longHeight = GetRebarRadius(longRebarStyleID)

-- Height of placement of transverse rebars
local transHeight = GetRebarRadius(longRebarStyleID) * 2 + GetRebarRadius(transRebarStyleID)

-- Height of placement of symbolic representation
local symbolicHeight = GetRebarRadius(longRebarStyleID) + GetRebarRadius(transRebarStyleID)

-- Creating a curve for longitudinal rebars
local longRebarLine = CreateLineSegment3D(Point3D(-length / 2, -width / 2, longHeight),
    Point3D(length / 2, -width / 2, longHeight))

-- Vector of the direction of the longitudinal rebars layout
local longVector = Vector3D(0, 1, 0)

-- Creating a curve for transverse rebars
local transRebarLine = CreateLineSegment3D(Point3D(-length / 2, -width / 2, transHeight),
    Point3D(-length / 2, width / 2, transHeight))

-- Vector of the direction of the transverse rebars layout
local transVector = Vector3D(1, 0, 0)

-- Creation of longitudinal rebars
CreateRebarLayoutWithFreeEnd(longRebarStyleID, longRebarLine, width, transFreeEnd, longStep, longVector)

-- Creation of transverse rebars
CreateRebarLayoutWithFreeEnd(transRebarStyleID, transRebarLine, length, longFreeEnd, transStep, transVector)

-- Create the symbolic model geometry
local symbolicGeometry = ModelGeometry()

-- Create the symbolic model geometry placement
local symbolicGeometryPlacement = Placement3D(Point3D(0, 0, symbolicHeight), Vector3D(0, 0, 1), Vector3D(1, 0, 0))

-- Add a symbol to it and place symbol so that it is located in the middle of the body and coincides with its contour.
symbolicGeometry:AddGeometrySet2D(MakeSymbolicGeometrySet(), symbolicGeometryPlacement)

-- Set the symbolic geometry for the style.
Style.SetSymbolicGeometry(symbolicGeometry)
