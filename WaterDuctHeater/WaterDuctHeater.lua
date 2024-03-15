-- Get style parameters.
local parameters = Style.GetParameterValues()

local width = parameters.Dimensions.HeaterWidth
local height = parameters.Dimensions.HeaterHeight
local depth = parameters.Dimensions.HeaterDepth

local coolantNominalDiameter = parameters.Dimensions.CoolantNominalDiameter
local distanceBetweenCoolantNipples = parameters.Dimensions.DistanceBetweenCoolantNipples
local coolantNippleLength = parameters.Dimensions.CoolantNippleLength

-- Calculate common parameters
local isCircleDuct = parameters.Dimensions.DuctShape == "Circle"
local isCoolantNipplesPositionAlong = parameters.Dimensions.CoolantNipplesPosition == "Along"

-- Determine the position of nipples
local inletPlace = Placement3D(
                        Point3D(-width / 2, 0, 0),
                        Vector3D(-1, 0, 0), Vector3D(0, 1, 0))
local outletPlace = Placement3D(
                        Point3D(width / 2, 0, 0),
                        Vector3D(1, 0, 0), Vector3D(0, 1, 0))

-- Сoolant port placement is determined by the technical task. 
-- It depends on the coolant nipples position on the duct.
local topCoolantPlace = isCoolantNipplesPositionAlong and
        Placement3D(
            Point3D(width / 2, -depth / 2 + coolantNominalDiameter, distanceBetweenCoolantNipples / 2),
            Vector3D(1, 0, 0), Vector3D(0, 1, 0))
    or
        Placement3D(
            Point3D(-coolantNominalDiameter, -depth / 2, distanceBetweenCoolantNipples / 2),
            Vector3D(0, -1, 0), Vector3D(0, 1, 0))

local bottomCoolantPlace = isCoolantNipplesPositionAlong and
        Placement3D(
            Point3D(width / 2, -depth / 2 + coolantNominalDiameter, -distanceBetweenCoolantNipples / 2),
            Vector3D(1, 0, 0), Vector3D(0, 1, 0))
    or
        Placement3D(
            Point3D(coolantNominalDiameter, -depth / 2, -distanceBetweenCoolantNipples / 2),
            Vector3D(0, -1, 0), Vector3D(0, 1, 0))

-- Function hides irrelevant parameters for ports based on the port form.
-- Takes the port name as input.
function HideIrrelevantDuctPortParams(portName)
    -- Set the visibility of parameters
    Style.GetParameter(portName, "NominalDiameter"):SetVisible(isCircleDuct)
    Style.GetParameter(portName, "NominalWidth"):SetVisible(not isCircleDuct)
    Style.GetParameter(portName, "NominalHeight"):SetVisible(not isCircleDuct)
end

-- Function hides irrelevant parameters for ports based on the connection type. This is necessary because when working
-- with piping systems, the user can choose a Threaded connection, and for that, the diameter values are specified in
-- inches from a preset list.
-- Takes the port name as input.
function HideIrrelevantPipePortParams(portName)
    -- Determine if the connection type is threaded
    local isThread =
        Style.GetParameter(portName, "ConnectionType"):GetValue() ==
            PipeConnectorType.Thread
    -- Set the visibility of parameters
    Style.GetParameter(portName, "ThreadSize"):SetVisible(isThread)
    Style.GetParameter(portName, "NominalDiameter"):SetVisible(not isThread)
end

-- Hide irrelevant parameters for ports
HideIrrelevantDuctPortParams("Inlet")
HideIrrelevantDuctPortParams("Outlet")
HideIrrelevantPipePortParams("Coolant")

-- Create solid
-- Create heater body
local heaterBody = CreateBlock(width, depth, height):Shift(0, 0, -height / 2)

-- Function for create a duct nippel
function CreateDuctNipple(params)
    return isCircleDuct and
            CreateRightCircularCylinder(params.NominalDiameter / 2, params.NippleLength)
        or
            CreateBlock(params.NominalWidth, params.NominalHeight, params.NippleLength)
end

-- Create duct nipples
local inletNipple  = CreateDuctNipple(parameters.Inlet):Transform(inletPlace:GetMatrix())
local outletNipple = CreateDuctNipple(parameters.Outlet):Transform(outletPlace:GetMatrix())

-- Function for create coolant
function CreateCoolant()
    local initCoolantConnector = CreateRightCircularCylinder(coolantNominalDiameter / 2, coolantNippleLength)
    local topCoolantNipple = initCoolantConnector:Clone():Transform(topCoolantPlace:GetMatrix())
    local bottomCoolantNipple = initCoolantConnector:Clone():Transform(bottomCoolantPlace:GetMatrix())
    local coolant = Unite(topCoolantNipple, bottomCoolantNipple)

    if not isCoolantNipplesPositionAlong then
        -- Creating and adding collectors
        local initCollector = CreateRightCircularCylinder(coolantNominalDiameter / 2, distanceBetweenCoolantNipples + coolantNominalDiameter)
        local collectorYOffsrt = -depth / 2 - 0.3 * coolantNippleLength
        local collectorZOffsrt = -(distanceBetweenCoolantNipples + coolantNominalDiameter) / 2
        local leftCollectorPlace = Placement3D(
                            Point3D(-coolantNominalDiameter, collectorYOffsrt, collectorZOffsrt),
                            Vector3D(0, 0, 1), Vector3D(0, 1, 0))
        local leftCollector = initCollector:Clone():Transform(leftCollectorPlace:GetMatrix())
        local rightCollectorPlace = Placement3D(
                         Point3D(coolantNominalDiameter, collectorYOffsrt, collectorZOffsrt),
                         Vector3D(0, 0, 1), Vector3D(0, 1, 0))
        local rightCollector = initCollector:Clone():Transform(rightCollectorPlace:GetMatrix())

        coolant = Unite({coolant, leftCollector, rightCollector})
    end
    return coolant
end

-- Solid assembly
local solid = Unite({heaterBody, inletNipple, outletNipple, CreateCoolant()})

-- Create the detailed model geometry
local detailedGeometry = ModelGeometry()
-- add the solid to it
detailedGeometry:AddSolid(solid)
-- Set the detailed geometry for the style.
Style.SetDetailedGeometry(detailedGeometry)

-- Function for creating symbol and symbolic geometry from rectangle and diagonal line
function CreateHeaterSymbol(width, height)
    local geometry = GeometrySet2D()
    -- Add Rectangle
    local contour = CreateRectangle2D(Point2D(0, 0), 0, width, height)
    geometry:AddCurve(contour)
    geometry:AddMaterialColorSolidArea(FillArea(contour))
    -- Add lineSegment
    local halfWidth = width / 2;
    local halfHeight = height / 2;
    local p0 = Point2D(halfWidth, halfHeight)
    local p1 = Point2D(-halfWidth, -halfHeight)
    local lineSegment = CreateLineSegment2D(p0, p1)
    geometry:AddCurve(lineSegment)

    return geometry
end

-- Create symbol model geometry.
local symbolGeometry = ModelGeometry()
-- Add the created set of primitives to the symbol geometry.
symbolGeometry:AddGeometrySet2D(CreateHeaterSymbol(2, 3))
-- Set the symbol geometry for the style.
Style.SetSymbolGeometry(symbolGeometry)

-- Create symbolic model geometry.
local symbolicGeometry = ModelGeometry()
-- Add the created set of primitives to the symbolic geometry.
symbolicGeometry:AddGeometrySet2D(CreateHeaterSymbol(width, depth))
-- Set the symbolic geometry for the style.
Style.SetSymbolicGeometry(symbolicGeometry)

-- Configure ports

-- Support functions
-- Functions for shifting a placement according to its Z vector
function ShiftPlacementByZ(placement, shift)
    local vector = placement:GetZAxisDirection()
    return placement:Clone():Shift(vector:GetX() * shift, vector:GetY() * shift, vector:GetZ() * shift)
end

-- Function sets parameters for duct port.
function SetDuctParameters(port, portParameters)
    if isCircleDuct then
        -- Set connection type and circular profile
        port:SetDuctParameters(portParameters.ConnectionType,
            CircularProfile(portParameters.NominalDiameter))
    else
        -- Otherwise, connection type and rectangular profile
        port:SetDuctParameters(portParameters.ConnectionType,
            RectangularProfile(portParameters.NominalWidth, portParameters.NominalHeight))
    end
end

-- Function sets parameters for pipe port.
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

-- Configure the Inlet port
local inletPort = Style.GetPort("Inlet")
inletPort:SetPlacement(ShiftPlacementByZ(inletPlace, parameters.Inlet.NippleLength))
SetDuctParameters(inletPort, parameters.Inlet)

-- Configure the Outlet port
local outletPort = Style.GetPort("Outlet")
outletPort:SetPlacement(ShiftPlacementByZ(outletPlace, parameters.Outlet.NippleLength))
SetDuctParameters(outletPort, parameters.Outlet)

-- Configure the top coolant port
local topCoolantPort = Style.GetPort("TopCoolant")
topCoolantPort:SetPlacement(ShiftPlacementByZ(topCoolantPlace, coolantNippleLength))
SetPipeParameters(topCoolantPort, parameters.Coolant)

-- Configure the bottom coolant port
local bottomCoolantPort = Style.GetPort("BottomCoolant")
bottomCoolantPort:SetPlacement(ShiftPlacementByZ(bottomCoolantPlace, coolantNippleLength))
SetPipeParameters(bottomCoolantPort, parameters.Coolant)
