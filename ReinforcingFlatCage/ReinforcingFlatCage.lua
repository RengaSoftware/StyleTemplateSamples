-- Get the parameters of the current style.
local parameters = Style.GetParameterValues()

local length = parameters.Dimensions.Length
local width = parameters.Dimensions.Width
local leftDowels = parameters.Dimensions.LeftDowelLength
local rightDowels = parameters.Dimensions.RightDowelLength
local longRebarStyleID = parameters.LongitudinalReinforcement.RebarStyleId
local longFreeEnd = parameters.LongitudinalReinforcement.FreeEnd
local transRebarStyleID = parameters.TransverseReinforcement.RebarStyleId
local transStep = parameters.TransverseReinforcement.Step
local transFreeEnd = parameters.TransverseReinforcement.FreeEnd

-- The function of getting the rebar radius by ID
function GetRebarRadius(rebarStyleId)
    local style = Project.GetRebarStyle(rebarStyleId)
    local parameters = CastToParameterContainer(style)
    return parameters:GetParameterValues().RebarDiameter / 2
end

-- Function creates a symbolic representation of the Reinforcement unit for display on drawings.
function MakeSymbolicGeometrySet()
    local rectangle = CreateRectangle2D(Point2D(0, length / 2), 0, width, length)
    local line = CreateLineSegment2D(Point2D(-width / 2, 0), Point2D(width / 2, length))
    local geometrySet = GeometrySet2D()
    geometrySet:AddCurve(rectangle)
    geometrySet:AddCurve(line)
    return geometrySet
end

-- Getting the vertical rebar radius
local longRebarRadius = GetRebarRadius(longRebarStyleID)

-- Getting the horisontal rebar radius
local transRebarRadius = GetRebarRadius(transRebarStyleID)

-- Сalculate the width along the axes of the vertical reinforcing bars
local longRebarsWidth = width - (transFreeEnd + longRebarRadius) * 2

-- The function of сreating vertical rebar
function longRebar(rebarStyleID, dowles, shiftX)
    local line = CreateLineSegment3D(Point3D(shiftX, 0, 0), Point3D(shiftX, 0, length + dowles))
    Style.AddRebar(rebarStyleID, line)
end

-- Creating a vertical rebar lines
longRebar(longRebarStyleID, leftDowels, -longRebarsWidth / 2)
longRebar(longRebarStyleID, rightDowels, longRebarsWidth / 2)

-- Get the vertical displacement of the first horizontal rebar
local transRebarShiftZ = longFreeEnd + transRebarRadius

-- Get the horisontal displacement of the horizontal rebars
local transRebarShiftY = longRebarRadius + transRebarRadius

-- Get the number of horizontal rebars
local layoutLength = length - transRebarShiftZ * 2
local number = math.floor(layoutLength / transStep)

-- Creating a horisontal rebar line
local transRebarCurve = CreateLineSegment3D(Point3D(-width / 2, -transRebarShiftY, transRebarShiftZ),
    Point3D(width / 2, -transRebarShiftY, transRebarShiftZ))

-- Creating a horisontal rebar set
Style.AddRebarSet(transRebarStyleID, transRebarCurve, Vector3D(0, 0, 1), transStep, number + 1)

-- Create the symbolic model geometry,
local symbolicGeometry = ModelGeometry()

-- Add a symbol to the middle of the body.
symbolicGeometry:AddGeometrySet2D(MakeSymbolicGeometrySet(),
    Placement3D(Point3D(0, 0, 0), Vector3D(0, -1, 0), Vector3D(1, 0, 0)))

-- Set the symbolic geometry for the style.
Style.SetSymbolicGeometry(symbolicGeometry)

