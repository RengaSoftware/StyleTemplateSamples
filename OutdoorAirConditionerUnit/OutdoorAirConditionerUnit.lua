-- Getting style parameter values
local parameters = Style.GetParameterValues()

local bodyWidth = parameters.Dimensions.Width
local bodyHeight = parameters.Dimensions.Height
local bodyDepth = parameters.Dimensions.Depth

-- Function creates the body solid of the air conditioner unit: a parallelepiped with dimensions specified in the parameters.
function MakeBody()
  return CreateBlock(bodyWidth, bodyDepth, bodyHeight)
end

-- Function creates the mounting plate solid: a parallelepiped with dimensions specified in the parameters.
-- Takes the offset from the left edge of the air conditioner unit's body as an argument.
function MakeMountPlate(offset)
  -- Define the dimensions of the mounting plate
  local width = parameters.Dimensions.PlateWidth
  local height = parameters.Dimensions.PlateHeight
  local depth = parameters.Dimensions.PlateDepth
  -- Create the mounting plate. The center of the mounting plate's plane coincides with the center of the bottom plane
  -- of the body.
  local mountPlate = CreateBlock(width, depth, height)
  -- Shift the mounting plate to the left by half of the body's width to align its center with the left edge of the
  -- body. Then shift it by the amount specified in the parameters,
  -- thus placing the center of the mounting plate at the desired distance from the left edge of the body.
  mountPlate:Shift(-bodyWidth / 2 + offset, 0, 0)
  -- Shift the mounting plate downward by its height to align its upper plane with the lower plane of the body.
  mountPlate:Shift(0, 0, -height)
  return mountPlate
end

-- Function returns the length of the branch specified in the technical task.
-- Takes the diameter of the branch as an argument.
function GetBranchLength(diameter)
  -- The length of the branch is equal to three diameters according to the technical task.
  return diameter * 3
end

-- Function returns the length of the valve body specified in the technical task.
-- Takes the diameter of the branch as an argument.
function GetValveBodyLength(diameter)
  -- The length of the valve body is equal to four diameters according to the technical task.
  return diameter * 4
end

-- Function creates the valve solid in the valve coordinate system, which consists of two cylinders.
-- Takes the diameter of the branch as an argument.
function MakeValve(diameter)
  -- Define the dimensions of the branch
  local radius = diameter / 2
  local branchLength = GetBranchLength(diameter)
  local valveBodyLength = GetValveBodyLength(diameter)
  -- Create the valve body cylinder
  local valveBody = CreateRightCircularCylinder(radius * 2, valveBodyLength)
  -- Rotate the valve body so that it points in the X direction
  valveBody:Rotate(CreateYAxis3D(), math.pi / 2)
  -- Create the branch cylinder
  local branch = CreateRightCircularCylinder(radius, branchLength)
  -- Rotate the branch by 45 degrees relative to the X axis
  branch:Rotate(CreateXAxis3D(), -math.pi / 4)
  -- Shift the branch by half of the length of valve body to place it in the middle of the valve body
  branch:Shift(valveBodyLength / 2, 0, 0)
  -- Return the result of combining the two bodies
  return Unite(valveBody, branch)
end

-- Function creates a symbol representing a fan.
function MakeFanSymbol()
  -- Ratios of the symbol dimensions to the dimensions of the body
  local widthRatio = 0.52
  local heightRatio = 0.8
  local filletRadiusRatio = 0.2
  -- Define the dimensions of the symbol
  local width = bodyWidth * widthRatio
  local height = bodyHeight * heightRatio
  -- Create a rectangle. The dimensions correspond to the dimensions of the fan, with the bottom-left corner coinciding
  -- with the origin.
  local rectangle = CreateRectangle2D(Point2D(width / 2, height / 2), 0, width, height)
  -- Round the corners of the rectangle
  FilletCorners2D(rectangle, math.min(width, height) * filletRadiusRatio)
  -- Create a set of geometric primitives
  local geometrySet = GeometrySet2D()
  -- Add the rectangle as a curve to the geometric set
  geometrySet:AddCurve(rectangle)
  -- Return the resulting symbol
  return geometrySet
end

-- Function creates a symbolic representation of the air conditioner unit for display on drawings.
function MakeSymbolicGeometrySet()
  -- Create a rectangle. The width and height of the rectangle match the width and height of the body. Consider that
  -- the center of the bottom face of the body coincides with the origin.
  local curve = CreateRectangle2D(Point2D(0, bodyHeight / 2), 0, bodyWidth, bodyHeight)
  -- Create a set of geometric primitives.
  local geometrySet = GeometrySet2D()
  -- Add the curve to the geometric set.
  geometrySet:AddCurve(curve)
  -- Create a filled area within the rectangle.
  local fillArea = FillArea(curve)
  -- Add the area with material color fill to the geometric set.
  geometrySet:AddMaterialColorSolidArea(fillArea)
  -- Return the resulting set: a rectangle with fill.
  return geometrySet
end

-- Function determines the position of the valve on the right side of the body.
-- Takes depth and height offsets as arguments.
function GetValvePlacement(depthOffset, heightOffset)
  return Placement3D(
      Point3D(bodyWidth / 2,
              -bodyDepth / 2 + depthOffset,
              heightOffset),
      Vector3D(0, 0, 1),
      Vector3D(1, 0, 0))
end

-- Function determines the position of the port relative to the branch's position on the body.
-- Takes the diameter of the branch as an argument.
function GetPortPlacement(diameter)
  -- Define the dimensions of the branch.
  local branchLength = GetBranchLength(diameter)
  local valveBodyLength = GetValveBodyLength(diameter)
  -- Create a local coordinate system and rotate it by 45 degrees, as specified in the technical task.
  local result = Placement3D(Point3D(valveBodyLength / 2, 0, branchLength), Vector3D(0, 0, 1), Vector3D(1, 0, 0))
  result:Rotate(CreateXAxis3D(), -math.pi / 4)
  return result
end

-- Function hides irrelevant parameters for ports based on the connection type. This is necessary because when working
-- with piping systems, the user can choose a Threaded connection, and for that, the diameter values are specified in 
-- inches from a preset list.
-- Takes the port name as input.
function HideIrrelevantPortParams(portName)
  -- Determine if the connection type is threaded
  local isThread = Style.GetParameter(portName, "ConnectionType"):GetValue() == PipeConnectorType.Thread
  -- Set the visibility of parameters
  Style.GetParameter(portName, "ThreadSize"):SetVisible(isThread)
  Style.GetParameter(portName, "NominalDiameter"):SetVisible(not isThread)
end

-- Function sets parameters for ports based on the connection type.
function SetPipeParameters(port, portParameters)
  -- Determine the connection type of the port
  local connectionType = portParameters.ConnectionType
  -- If the connection type is threaded,
  if connectionType == PipeConnectorType.Thread then
    -- set the port diameter in inches.
    port:SetPipeParameters(connectionType, portParameters.ThreadSize)
  else
    -- Otherwise, set the diameter in millimeters.
    port:SetPipeParameters(connectionType, portParameters.NominalDiameter)
  end
end

-- Hide irrelevant parameters for ports
HideIrrelevantPortParams("Gas")
HideIrrelevantPortParams("Fluid")
HideIrrelevantPortParams("Sewage")

-- Determine the positions of the valves
local gasValvePlacement = GetValvePlacement(parameters.Gas.ValveDepthOffset, parameters.Gas.ValveHeightOffset)
local fluidValvePlacement = GetValvePlacement(parameters.Fluid.ValveDepthOffset, parameters.Fluid.ValveHeightOffset)

-- Determine the positions of the ports
local gasPortPlacement = GetPortPlacement(parameters.Gas.Diameter):Transform(gasValvePlacement:GetMatrix())
local fluidPortPlacement = GetPortPlacement(parameters.Fluid.Diameter):Transform(fluidValvePlacement:GetMatrix())
local sewagePlacement = Placement3D(Point3D(0, 0, 0), Vector3D(0, 0, -1), Vector3D(1, 0, 0))
local controlPlacement = Placement3D(Point3D(bodyWidth / 2, 0, bodyHeight / 2), Vector3D(1, 0, 0), Vector3D(0, 0, -1)) 
local powerSupplyPlacement = controlPlacement:Clone():Shift(0, 0, 30)

-- Configure the ports
local gasPort = Style.GetPort("Gas")
SetPipeParameters(gasPort, parameters.Gas)
gasPort:SetPlacement(gasPortPlacement)

local fluidPort = Style.GetPort("Fluid")
SetPipeParameters(fluidPort, parameters.Fluid)
fluidPort:SetPlacement(fluidPortPlacement)

local sewagePort = Style.GetPort("Sewage")
SetPipeParameters(sewagePort, parameters.Sewage)
sewagePort:SetPlacement(sewagePlacement)

local powerSupplyPort = Style.GetPort("PowerSupply")
powerSupplyPort:SetPlacement(powerSupplyPlacement)

local controlPort = Style.GetPort("Control")
controlPort:SetPlacement(controlPlacement)

-- Create the detailed model geometry of the air conditioner unit, consisting of the body, two mounting plates, and two
-- valves.
local detailedSolid = Unite({
    MakeBody(),
    MakeMountPlate(parameters.Dimensions.LeftPlateOffset),
    MakeMountPlate(parameters.Dimensions.RightPlateOffset),
    MakeValve(parameters.Gas.Diameter):Transform(gasValvePlacement:GetMatrix()),
    MakeValve(parameters.Fluid.Diameter):Transform(fluidValvePlacement:GetMatrix())
})

-- Determine the position of the fan symbol. It should be located on the front plane of the body, at a distance of 0.08
-- of the width from the left edge, and at 0.1 of the height from the bottom edge of the body.
-- The Z-axis of the fan symbol is oriented opposite to the Y-axis of the global coordinate system.
local fanSymbolPlace = Placement3D(
    Point3D(-bodyWidth / 2 + bodyWidth * 0.08, -bodyDepth / 2, bodyHeight * 0.1),
    Vector3D(0, -1, 0),
    Vector3D(1, 0, 0))

-- Create the detailed model geometry,
local detailedGeometry = ModelGeometry()
-- add the body to it,
detailedGeometry:AddSolid(detailedSolid)
-- add the fan symbol to it.
detailedGeometry:AddGeometrySet2D(MakeFanSymbol(), fanSymbolPlace)

-- Set the detailed geometry for the style.
Style.SetDetailedGeometry(detailedGeometry)

-- Create the symbolic model geometry,
local symbolicGeometry = ModelGeometry()
-- add a symbol to it and place symbol so that it is located in the middle of the body and coincides with its contour.
symbolicGeometry:AddGeometrySet2D(MakeSymbolicGeometrySet(), 
                                  Placement3D(Point3D(0, 0, 0), Vector3D(0, -1, 0), Vector3D(1, 0, 0)))

-- Set the symbolic geometry for the style.
Style.SetSymbolicGeometry(symbolicGeometry)
