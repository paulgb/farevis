
d3 = require 'd3'
moment = require 'moment'

class Flight
  constructor: (@legs, @price, @startTime, @endTime, @index) ->

  superior: (otherFlight) ->
    # return true iff this flight is superior to otherFlight
    
    # is otherFlight superior to this flight?
    if otherFlight.startTime > @startTime
      return false
    if otherFlight.endTime < @endTime
      return false
    if otherFlight.price < @price
      return false

    # Is this flight superior to otherFlight?
    if otherFlight.startTime < @startTime
      return true
    if otherFlight.endTime > @endTime
      return true
    if otherFlight.price > @price
      return true

    # Arbitrary Tiebreaker
    if otherFlight.index <= @index
      return false
    return true

class Leg
  constructor: (@origin, @destination, @departure, @arrival, @carrier) ->

class Airport
  constructor: (@code, @city, @timezone, @type) ->

  setTz: (@tz) ->
    @city.tz = @tz

  setMinHops: (hops) ->
    if (not @hops?) or hops < @hops
      @hops = hops

  @compare: (a, b) ->
    if a.type == 'origin' or b.type == 'destination'
      return -1
    else if a.type == 'destination' or b.type == 'origin'
      return 1
    else if a.hops < b.hops
      return -1
    else if a.hops > b.hops
      return 1
    else
      return 0

class City
  constructor: (@code, @name) ->

class Carrier
  constructor: (@code, @name, @color) ->

class Gate
  constructor: (@code, @airport) ->

class FlightEvent
  constructor: (@flightIndex, @airport, @time, @type) ->

class FlightVisualization
  constructor: (@ita) ->

  createSVG: ->
    container = d3.select('#solutionPane td.itaRoundedPaneMain')
    container.select('*').remove()
    container.attr('style', 'height: 600px')
    @svg = container.append('svg:svg')
    @width = @svg[0][0].offsetWidth
    @height = @svg[0][0].offsetHeight

  prepareScales: ->
    @airportScale = d3.scale.ordinal()
    @airportScale.domain(@airportsList)
    @airportScale.rangeBands([20, @height])

    @dateScale = d3.time.scale()
    @dateScale.domain([@minDeparture, @maxArrival])
    @dateScale.range([40, @width])

  drawYAxis: ->
    @svg.selectAll('text.yAxis')
      .data(@airportsList)
      .enter()
        .append('text')
        .attr('x', 10)
        .attr('y', @airportScale)
        .style('dominant-baseline', 'middle')
        .text((airport) -> airport)

  draw: ->
    @get_data()
    @createSVG()
    @prepareScales()
    @drawYAxis()

    legPath = (leg) =>
      x1 = @dateScale(leg.departure)
      y1 = @airportScale(leg.origin.code)
      x2 = @dateScale(leg.arrival)
      y2 = @airportScale(leg.destination.code)
      "M #{x1},#{y1} L #{x2},#{y2}"

    @svg.selectAll('g.flight')
        .data(@flights)
        .enter()
          .append('g')
          .selectAll('path')
          .data((x) -> x.legs)
          .enter()
            .append('path')
            .style('stroke', (leg) -> leg.carrier.color)
            .style('stroke-width', '3')
            .attr('d', legPath)

  get_data: ->
    itaData = @ita.flightsPage.flightsPanel.flightList
    carrierToColorMap = @ita.flightsPage.matrix.stopCarrierMatrix.carrierToColorMap
    isoOffsetInMinutes = @ita.isoOffsetInMinutes

    @cities = {}
    @airports = {}
    @flights = []
    @carriers = {}

    # Flight time range
    @maxArrival = moment(itaData.maxArrival)
    @minDeparture = moment(itaData.minDeparture)

    # Load City data
    for code, itaCity of itaData.data.cities
      city = new City(code, itaCity.name)
      @cities[code] = city

    # Load Airport data
    originCodes = itaData.originCodes
    destinationCodes = itaData.destinationCodes
    for code, itaAirport of itaData.data.airports
      if code in originCodes
        type = 'origin'
      else if code in destinationCodes
        type = 'destination'
      else
        type = 'connection'
      airport = new Airport(code, @cities[itaAirport.city],
        itaAirport.name, type)
      @airports[code] = airport

    # Load Carrier Data
    for code, itaCarrier of itaData.data.carriers
      carrier = new Carrier(code, itaCarrier.shortName,
        carrierToColorMap[code])
      @carriers[code] = carrier

    # Load Flight Data
    for solution, index in itaData.summary.solutions
      legs = []
      price = parseFloat(solution.itinerary.pricings[0].displayPrice.substring(3))
      itaLegs = solution.itinerary.slices[0].legs

      firstLeg = itaLegs[0]
      lastLeg = itaLegs[itaLegs.length - 1]

      # Flight duration
      startTime = moment(firstLeg.departure)
      endTime = moment(lastLeg.arrival)

      lastLeg = null
      for itaLeg, legIndex in itaLegs
        airportOrigin = @airports[itaLeg.origin]
        airportDestination = @airports[itaLeg.destination]
        # Set time zones
        airportOrigin.setTz(isoOffsetInMinutes(itaLeg.departure))
        airportDestination.setTz(isoOffsetInMinutes(itaLeg.arrival))

        # Update hops table
        airportOrigin.setMinHops(legIndex)
        airportDestination.setMinHops(legIndex + 1)

        # Save leg
        leg = new Leg(airportOrigin,
                      airportDestination,
                      moment(itaLeg.departure),
                      moment(itaLeg.arrival),
                      @carriers[itaLeg.carrier])
        legs.push(leg)

      flight = new Flight(legs, price, startTime, endTime, index)
      @flights.push(flight)

    # Get rid of duplicate and inferior flights
    trimmed_flights = []
    for flight1 in @flights
      trim = false
      for flight2 in @flights
        if flight2.superior(flight1)
          trim = true
          break
      if not trim
        trimmed_flights.push(flight1)
    @flights = trimmed_flights

    @airportsList = (airport for i, airport of @airports).sort(Airport.compare)
    @airportsList = (airport.code for airport in @airportsList)

main = ->
  vis = new FlightVisualization(ita)
  vis.draw()

main()

