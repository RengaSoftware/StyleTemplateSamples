-- Get the parameters of the current style.
local parameters = Style.GetParameterValues()
-- Retrieve the Dimensions table from the style parameters, representing pipeline element dimensions.
local dimensions = parameters.Dimensions

-- Return a transformation matrix for rotating branch elements.
function GetBranchRotator(zAngle, xAngle)
  local matrix = Matrix3D()
  matrix:Rotate(CreateZAxis3D(), math.rad(zAngle))
  matrix:Rotate(CreateXAxis3D(), math.rad(xAngle))
  return matrix
end

-- Function to create the solid of a cross branch with specified parameters.
function MakeBranch(diameter, length, rotator)
  local branchSolid = CreateRightCircularCylinder(diameter / 2, length)
  branchSolid:Rotate(CreateYAxis3D(), math.pi / 2)
  branchSolid:Transform(rotator)
  return branchSolid
end

-- Function to create the solid of the main cross pipe.
function MakeBody()
  -- Determine the length of the main pipe.
  local length = dimensions.CenterToOutletDistance + dimensions.InletToCenterDistance
  -- Create the main pipe.
  local solid = CreateRightCircularCylinder(dimensions.CrossOutsideDiameter / 2, length)
  solid:Rotate(CreateYAxis3D(), math.pi / 2)
  solid:Shift(-dimensions.InletToCenterDistance, 0, 0)
  return solid
end

-- Function to create a sphere solid for connecting the main pipe and branches if the branch diameter 
-- is greater than the main pipe diameter.
function MakeSphere()
  if dimensions.Branch1OutsideDiameter > dimensions.CrossOutsideDiameter 
    or dimensions.Branch2OutsideDiameter > dimensions.CrossOutsideDiameter then
      return CreateSphere(math.max(dimensions.Branch1OutsideDiameter, dimensions.Branch2OutsideDiameter) / 2)
  end
  return nil
end

-- Function to create a symbol for the main pipe. 
-- Takes inlet length and outlet length as input.
function MakeBodySymbol(inletLength, outletLength)
  local geometry = GeometrySet2D()
  local line = CreateLineSegment2D(Point2D(-inletLength, 0), Point2D(outletLength, 0))
  geometry:AddCurve(line)
  return geometry
end

-- Function to create a symbol for a branch. 
-- Takes branch length as input.
function MakeBranchSymbol(branchLength)
  local geometry = GeometrySet2D()
  local line = CreateLineSegment2D(Point2D(0, 0), Point2D(branchLength, 0))
  geometry:AddCurve(line)
  return geometry
end

-- Function to get the placement of a branch symbol.
function GetBranchSymbolPlacement(rotator)
  local placement = Placement3D(Point3D(0, 0, 0), Vector3D(0, 0, 1), Vector3D(1, 0, 0))
  placement:Transform(rotator)
  return placement
end

-- Function to get the placement of a branch port.
function GetBranchPortPlacement(length, rotator)
  local placement = Placement3D(Point3D(0, 0, 0), Vector3D(0, 0, 1), Vector3D(1, 0, 0))
  placement:Shift(0, 0, length)
  placement:Rotate(CreateYAxis3D(), math.pi / 2)
  placement:Transform(rotator)
  return placement
end

-- Function to create geometry from 2D primitives.
function MakeDrawingGeometry(inletLength, outletLength, branch1Length, branch2Length, branch1Rotator, branch2Rotator)
  local geometry = ModelGeometry()
  local bodySymbol = MakeBodySymbol(inletLength, outletLength)
  local branch1Symbol = MakeBranchSymbol(branch1Length)
  local branch2Symbol = MakeBranchSymbol(branch2Length)
  local branch1SymbolPlacement = GetBranchSymbolPlacement(branch1Rotator)
  local branch2SymbolPlacement = GetBranchSymbolPlacement(branch2Rotator)
  
  geometry:AddGeometrySet2D(bodySymbol)
  geometry:AddGeometrySet2D(branch1Symbol, branch1SymbolPlacement)
  geometry:AddGeometrySet2D(branch1Symbol, branch2SymbolPlacement)

  return geometry
end

-- Function to hide irrelevant parameters for a port based on the connection type. This is necessary 
-- because when working with pipeline systems, the user can choose a Threaded connection type, 
-- and for it, the diameter value is specified in inches from a predefined list.
-- Takes the port name as input.
function HideIrrelevantPortParams(portName)
  -- Determine whether the connection type is threaded.
  local isThread = Style.GetParameter(portName, "ConnectionType"):GetValue() == PipeConnectorType.Thread
  -- Set the visibility of parameters.
  Style.GetParameter(portName, "ThreadSize"):SetVisible(isThread)
  Style.GetParameter(portName, "NominalDiameter"):SetVisible(not isThread)
end

-- Function to set parameters for a port based on the connection type.
function SetPipeParameters(port, portParameters)
  -- Determine the connection type of the port.
  local connectionType = portParameters.ConnectionType
  -- If the connection type is threaded,
  if connectionType == PipeConnectorType.Thread then
    -- set the port diameter in inches.
    port:SetPipeParameters(connectionType, portParameters.ThreadSize)
  else
    -- Otherwise, set the diameter in millimeters for all other cases.
    port:SetPipeParameters(connectionType, portParameters.NominalDiameter)
  end
end

-- Hide irrelevant parameters for all ports.
HideIrrelevantPortParams("Port1")
HideIrrelevantPortParams("Port2")
HideIrrelevantPortParams("Branch1")
HideIrrelevantPortParams("Branch2")

local branch1Rotator = GetBranchRotator(dimensions.AngleBetweenOutletAndBranch1,
                                        dimensions.AngleBetweenBranch1AndBranch2 / 2)

local branch2Rotator = GetBranchRotator(dimensions.AngleBetweenOutletAndBranch2,
                                        -dimensions.AngleBetweenBranch1AndBranch2 / 2)

-- Define "Port 1" and set its placement and parameters.
local port1 = Style.GetPort("Port1")
port1:SetPlacement(Placement3D(Point3D(-dimensions.InletToCenterDistance, 0, 0),
                               Vector3D(-1, 0, 0),
                               Vector3D(0, 1, 0)))
SetPipeParameters(port1, parameters.Port1)

-- Define "Port 2" and set its placement and parameters.
local port2 = Style.GetPort("Port2")
port2:SetPlacement(Placement3D(Point3D(dimensions.CenterToOutletDistance, 0, 0),
                               Vector3D(1, 0, 0),
                               Vector3D(0, 1, 0)))
SetPipeParameters(port2, parameters.Port2)

-- Define "Branch 1" and set its placement and parameters.
local branch1 = Style.GetPort("Branch1")
branch1:SetPlacement(GetBranchPortPlacement(dimensions.CenterToBranch1Distance, branch1Rotator))
SetPipeParameters(branch1, parameters.Branch1)

-- Define "Branch 2" and set its placement and parameters.
local branch2 = Style.GetPort("Branch2")
branch2:SetPlacement(GetBranchPortPlacement(dimensions.CenterToBranch2Distance, branch2Rotator))
SetPipeParameters(branch2, parameters.Branch2)

-- Create the main body, branches, and sphere.
local bodySolid = MakeBody()
local branch1Solid = MakeBranch(dimensions.Branch1OutsideDiameter,
                                dimensions.CenterToBranch1Distance, 
                                branch1Rotator)
local branch2Solid = MakeBranch(dimensions.Branch2OutsideDiameter,
                                dimensions.CenterToBranch2Distance,
                                branch2Rotator)
local sphere = MakeSphere()

-- Combine all created solids into one detailed body.
local detailedSolid = Unite({bodySolid, branch1Solid, branch2Solid, sphere})
-- Hide tangent edges.
detailedSolid:ShowTangentEdges(false)

-- Create detailed model geometry.
local detailedGeometry = ModelGeometry()
-- Add the solid to it.
detailedGeometry:AddSolid(detailedSolid)

-- Set detailed geometry for the style.
Style.SetDetailedGeometry(detailedGeometry)

-- Create symbolic geometry.
local symbolicGeometry = MakeDrawingGeometry(dimensions.InletToCenterDistance, 
                                             dimensions.CenterToOutletDistance,
                                             dimensions.CenterToBranch1Distance,
                                             dimensions.CenterToBranch2Distance,
                                             branch1Rotator,
                                             branch2Rotator)

-- Set symbolic geometry for the style.
Style.SetSymbolicGeometry(symbolicGeometry)

--  Create symbol geometry.
local armLength = 2.5
local symbolGeometry = MakeDrawingGeometry(armLength, armLength, armLength, armLength, branch1Rotator, branch2Rotator)

-- Set symbol geometry for the style.
Style.SetSymbolGeometry(symbolGeometry)
