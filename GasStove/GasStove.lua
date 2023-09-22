-- Getting style parameter values
local parameters = Style.GetParameterValues()

local width = parameters.Dimensions.Width
local depth = parameters.Dimensions.Depth
local height = parameters.Dimensions.Height

-- Function creates a symbol representing an oven door.
function MakeOvenDoorSymbol()
    -- Define the dimensions of the symbol. The dimensions of the oven door depend on the dimensions of the gas stove, 
    -- see the technical task drawing.
    local doorWidth = width - 100
    local doorHeight = height / 2
    -- Create a rectangle.
    local rectangle = CreateRectangle2D(Point2D(0, doorHeight / 2), 0, doorWidth,
                                        doorHeight)
    -- Create a set of geometric primitives
    local geometrySet = GeometrySet2D()
    -- Add the rectangle as a curve to the geometric set
    geometrySet:AddCurve(rectangle)
    -- Return the resulting symbol
    return geometrySet
end

-- Determine the position of the oven door symbol
local doorSymbolPlace = Placement3D(Point3D(0, -depth / 2, height / 4),
                                    Vector3D(0, -1, 0), Vector3D(1, 0, 0))

-- Function creates a symbol representing a cooking surface with 4 rings 
function MakeCookingSurfaceSymbol()
    -- Diameter is equal to 120, see technical task drawing
    local radius = 120 / 2
    local x = width / 4
    local y = depth / 4
    -- Create rings
    local ring1 = CreateCircle2D(Point2D(x, y), radius)
    local ring2 = CreateCircle2D(Point2D(x, -y), radius)
    local ring3 = CreateCircle2D(Point2D(-x, -y), radius)
    local ring4 = CreateCircle2D(Point2D(-x, y), radius)
    -- Create rectangle for symbolic geometry   
    local rectangle = CreateRectangle2D(Point2D(0, 0), 0, width,
                                        depth)
    -- Create geometry set
    local geometrySet = GeometrySet2D()
    geometrySet:AddCurve(ring1)
    geometrySet:AddCurve(ring2)
    geometrySet:AddCurve(ring3)
    geometrySet:AddCurve(ring4)
    geometrySet:AddCurve(rectangle)
    -- Return the resulting symbol
    return geometrySet
end

-- Determine the position of the cooking surface symbol
local cookerSurfaceSymbolPlace = Placement3D(
                                     Point3D(0, 0, height),
                                     Vector3D(0, 0, 1), Vector3D(1, 0, 0))

-- Create the detailed model geometry,
local detailedGeometry = ModelGeometry()
-- add the body to it,
detailedGeometry:AddSolid(CreateBlock(width, depth, height))
-- add the symbols to it.
detailedGeometry:AddGeometrySet2D(MakeOvenDoorSymbol(), doorSymbolPlace)
detailedGeometry:AddGeometrySet2D(MakeCookingSurfaceSymbol(),
                                  cookerSurfaceSymbolPlace)

-- Set the detailed geometry for the style.
Style.SetDetailedGeometry(detailedGeometry)

local symbolicGeometry = ModelGeometry()
symbolicGeometry:AddGeometrySet2D(MakeCookingSurfaceSymbol(),
                                  cookerSurfaceSymbolPlace)

Style.SetSymbolicGeometry(symbolicGeometry)

-- Function hides irrelevant parameters for ports based on the connection type. This is necessary because when working
-- with piping systems, the user can choose a Threaded connection, and for that, the diameter values are specified in 
-- inches from a preset list.
-- Takes the port name as input.
function HideIrrelevantPortParams(portName)
    -- Determine if the connection type is threaded
    local isThread =
        Style.GetParameter(portName, "ConnectionType"):GetValue() ==
            PipeConnectorType.Thread
    -- Set the visibility of parameters
    Style.GetParameter(portName, "ThreadSize"):SetVisible(isThread)
    Style.GetParameter(portName, "NominalDiameter"):SetVisible(not isThread)
end

-- Hide irrelevant parameters for port
HideIrrelevantPortParams("Gas")

-- Function sets parameters for port.
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

-- Determine the position of the port
local gasPortPlace = Placement3D(
                         Point3D(width / 2 - 50, depth / 2, height - 100),
                         Vector3D(0, 1, 0), Vector3D(1, 0, 0))

-- Configure the port
local gasPort = Style.GetPort("Gas")
SetPipeParameters(gasPort, parameters.Gas)
gasPort:SetPlacement(gasPortPlace)
