-- Get style parameters.
local parameters = Style.GetParameterValues()
local dimensions = parameters.Dimensions

-- Create a cylinder with specified parameters.
local solid = CreateRightCircularCylinder(dimensions.OutsideDiameter / 2, dimensions.FaceToFaceDimension)
-- Create an axis corresponding to the global Y-axis.
local axisY = CreateYAxis3D()
-- Rotate the cylinder around the Y-axis by 90 degrees.
solid:Rotate(axisY, math.pi / 2)

-- Create detailed geometry.
local detailedGeometry = ModelGeometry()
-- Add the created cylinder to the detailed geometry.
detailedGeometry:AddSolid(solid)
-- Set the detailed geometry for the style.
Style.SetDetailedGeometry(detailedGeometry)

-- Function to create geometry from 2D primitives representing a line segment of length `radius * 2`.
function MakeGeometrySetForDrawing(radius)
  local geometry = GeometrySet2D()
  geometry:AddCurve(CreateLineSegment2D(Point2D(0, -radius), Point2D(0, radius)))
  return geometry
end

-- Define the radius for the symbol.
local symbolRadius = 1.25
-- Create a set of primitives for symbol geometry.
local symbolGeometrySet = MakeGeometrySetForDrawing(symbolRadius)
-- Create symbol geometry.
local symbolGeometry = ModelGeometry()
-- Add the created set of primitives to the symbol geometry.
symbolGeometry:AddGeometrySet2D(symbolGeometrySet)
-- Set the symbol geometry for the style.
Style.SetSymbolGeometry(symbolGeometry)

-- Create a set of primitives for symbolic geometry.
local symbolicGeometrySet = MakeGeometrySetForDrawing(dimensions.OutsideDiameter / 2)
-- Create symbolic geometry.
local symbolicGeometry = ModelGeometry()
-- Add the created set of primitives to the symbolic geometry.
symbolicGeometry:AddGeometrySet2D(symbolicGeometrySet)
-- Set the symbolic geometry for the style.
Style.SetSymbolicGeometry(symbolicGeometry)

-- Define the port connection type.
local connectionType = parameters.Port.ConnectionType
-- Figure out if the port connection type is threaded.
local isThread = parameters.Port.ConnectionType == PipeConnectorType.Thread

-- Set the visibility of parameters according to the port connection type.
Style.GetParameter("Port", "ThreadSize"):SetVisible(isThread)
Style.GetParameter("Port", "NominalDiameter"):SetVisible(not isThread)

-- Define the port placement. It is located at the origin, and its direction is opposite to the X-axis.
local portPlacement = Placement3D(Point3D(0, 0, 0), Vector3D(-1, 0, 0), Vector3D(0, 1, 0))

-- Get the port object from the style.
local port = Style.GetPort("Port")
-- Set the port placement.
port:SetPlacement(portPlacement)
-- Set the port parameters based on the connection type.
if isThread then
  port:SetPipeParameters(connectionType, parameters.Port.ThreadSize)
else
  port:SetPipeParameters(connectionType, parameters.Port.NominalDiameter)
end