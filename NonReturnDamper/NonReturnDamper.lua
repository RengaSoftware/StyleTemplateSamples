-- Getting style parameter values.
local parameters = Style.GetParameterValues()
local dimensions = parameters.Dimensions

-- Figure out if the Damper shape is "Circle".
local shapeIsCircle = dimensions.DamperShape == "Circle"

-- Function to create the solid of damper body.
function MakeBody()
  if shapeIsCircle then
    local cylinder = CreateRightCircularCylinder(dimensions.BodyDiameter / 2, dimensions.BodyLength)
    cylinder:Shift(0, 0, -dimensions.BodyLength / 2)
    cylinder:Rotate(CreateYAxis3D(), math.pi / 2)
    return cylinder
  end
  -- The Damper shape is "Rectangle".
  local block = CreateBlock(dimensions.BodyLength, dimensions.BodyWidth, dimensions.BodyHeight)
  block:Shift(0, 0, -dimensions.BodyHeight / 2)
  return block
end

-- Create the detailed solid
local detailedSolid = MakeBody()

-- Create detailed model geometry.
local detailedGeometry = ModelGeometry()
-- Add the solid to it.
detailedGeometry:AddSolid(detailedSolid)
-- Set detailed geometry for the style.
Style.SetDetailedGeometry(detailedGeometry)


-- Function to create geometry from 2D primitives.
function MakeGeometryForDrawing(width, length)
  local geometrySet = GeometrySet2D()

  local rectangle = CreateRectangle2D(Point2D(0, 0), 0, length, width)
  geometrySet:AddCurve(rectangle)
  geometrySet:AddMaterialColorSolidArea(FillArea(rectangle))
  
  -- The value from the technical task.
  local radiusFactor = 0.1
  local radius = math.min(width, length) * radiusFactor

  local diagonalLine = CreateLineSegment2D(Point2D(length / 2, width / 2), Point2D(-length / 2, -width / 2))
  geometrySet:AddCurve(diagonalLine)
      
  -- The value from the technical task.
  local circleCenterFactor = 0.158
  local circleCenter = Point2D(-length / 2 + length * circleCenterFactor, -width / 2 + width * circleCenterFactor)
  
  local circle = CreateCircle2D(circleCenter, radius)
  geometrySet:AddLineColorSolidArea(FillArea(circle))
  -- Add the circle curve so that the snap to the fill area borders works.
  geometrySet:AddCurve(circle)
  

  local geometry = ModelGeometry()
  geometry:AddGeometrySet2D(geometrySet)
  return geometry
end

--  Create symbol geometry.
local symbolGeometry = MakeGeometryForDrawing(3, 2)
-- Set symbol geometry for the style.
Style.SetSymbolGeometry(symbolGeometry)

-- Create symbolic geometry.
local symbolicGeometryWidth = shapeIsCircle and dimensions.BodyDiameter or dimensions.BodyWidth
local symbolicGeometryLength = dimensions.BodyLength
local symbolicGeometry = MakeGeometryForDrawing(symbolicGeometryWidth, symbolicGeometryLength)
-- Set symbolic geometry for the style.
Style.SetSymbolicGeometry(symbolicGeometry)


-- Hide irrelevant parameters for a port based on the damper shape.
Style.GetParameter("Dimensions", "BodyDiameter"):SetVisible(shapeIsCircle)
Style.GetParameter("Dimensions", "BodyWidth"):SetVisible(not shapeIsCircle)
Style.GetParameter("Dimensions", "BodyHeight"):SetVisible(not shapeIsCircle)


-- Function to set parameters for a port based on the connection type.
function SetDuctPortParameters(port, portParameters)
  if shapeIsCircle then 
    port:SetDuctParameters(portParameters.ConnectionType, CircularProfile(dimensions.BodyDiameter))
  else
    port:SetDuctParameters(portParameters.ConnectionType, RectangularProfile(dimensions.BodyWidth, dimensions.BodyHeight))
  end
end

-- Define "Inlet" and set its placement and parameters.
local inlet = Style.GetPort("Inlet")
inlet:SetPlacement(Placement3D(Point3D(-dimensions.BodyLength / 2, 0, 0), Vector3D(-1, 0, 0), Vector3D(0, 1, 0)))
SetDuctPortParameters(inlet,  parameters.Inlet)

-- Define "Outlet" and set its placement and parameters.
local outlet = Style.GetPort("Outlet")
outlet:SetPlacement(Placement3D(Point3D(dimensions.BodyLength / 2, 0, 0), Vector3D(1, 0, 0), Vector3D(0, 1, 0)))
SetDuctPortParameters(outlet, parameters.Outlet)