
# Flight Timeline Visualization
# By Paul Butler <vis@paulbutler.org> (2013)

# Visualize a set of flights ranging over a similar set of
# airports and a similar time span.

# This implementation works when bundled up with browserify
# (a node.js module) and injected into an ITA Matrix
# results page. This can be accomplished by means of a
# simple "bookmarklet" (see src/files/index.html).

d3 = require 'd3'
moment = require 'moment'

class Flight
  # Represent an itinerary for one flight
  constructor: (@legs, @price, @startTime, @endTime, @index) ->
    # Arguments
    #   legs        an array of Leg objects
    #   price       the price in local currency as a float
    #   startTime   the start time of this flight
    #   endTime     the end time of this flight
    #   index       any unique identifier for this flight

  superior: (otherFlight) ->
    # This function defines a partial order on flights.
    # A flight is considered superior if it starts at least
    # as late, ends at least as early, costs at most as much,
    # and at least one of those attributes are "better".
    # If all three attributes are the same, the tie is broken
    # by comparing the index field, which will always be different.
    # For two given flights, it is possible for neither to be
    # superior to eachother, ie.
    #   a.superior(b) == b.superior(a) == false
    # but two flights can never be superior to eachother.
    # No flight is superior to itself.
    
    # if the other flight is superior in at least one of
    # startTime, endTime, or price, we can rule out this
    # flight being superior to it
    if otherFlight.startTime > @startTime
      return false
    if otherFlight.endTime < @endTime
      return false
    if otherFlight.price < @price
      return false

    # Is this flight superior to otherFlight based
    # on startTime, endTime, or price attributes?
    if otherFlight.startTime < @startTime
      return true
    if otherFlight.endTime > @endTime
      return true
    if otherFlight.price > @price
      return true

    # Use the index as an arbitrary tiebreaker
    if otherFlight.index <= @index
      return false
    return true

class Leg
  # Represent a leg of a flight (connections are considered legs, usually
  # with the same origin and destination but occasionally different airports
  # within the same city)
  constructor: (@origin, @destination, @departure, @arrival, @carrier) ->
    # Arguments:
    #   origin        originating Airport
    #   destination   destination Airport
    #   departure     departure time
    #   arrival       arrival time
    #   carrier       Carrier object

    # "Gates" are used to differentiate itineraries that connect at
    # the same airport for overlapping time. We default to gate 0 until
    # the gate assigning algorithm in get_data decides otherwise
    @originGate = 0
    @destinationGate = 0

  setPrevLeg: (prevLeg) ->
    if prevLeg?
      @prevLeg = prevLeg
      prevLeg.nextLeg = this

class Airport
  # Represent an airport
  constructor: (@code, @name, @city, @timezone, @type) ->
    # Arguments
    #   code      the airport's code
    #   name      the name of the airport
    #   city      the airport's City
    #   timezone  the airport's UTC offset in minutes
    #   type      'origin', 'destionation', or 'connection'

    # Airports are grouped together when ground transit
    # is used between them in at least one itinerary.
    # The groups are used by the comparison operator to ensure
    # that airports in the same group are kept together.
    @group = [this]

    @numGates = 1     # number of gates, used by the gate assigning algorithm
    @freeGates = [0]  # set of free gates, used by the gate assigning algorihtm

  pairWith: (airport) ->
    # Pair this airport with another airport.
    # This is more complicated than you might expect, because we
    # have to consider the case where the airport we are paring
    # with is already paired to another airport (this can happen
    # with, for example, LGA, JFK, and EWR).
    if airport not in @group
      @group = @group.concat(airport.group)
      for member in @group
        member.group = @group

  setTz: (@tz) ->
    # Set the timezone of the airport (propogates to the city)
    @city.tz = @tz

  suggestMinHops: (hops) ->
    # Suggest a minimum number of hops; if it is lower than the
    # current minimum hops or no minimum hops value is unset,
    # take the suggested value as the number of hops.
    # Hops are the number of airports between an origin airport
    # and this airport, on the shortest route.
    if (not @hops?) or hops < @hops
      @hops = hops

  suggestMinDuration: (duration) ->
    # Suggest a minimum duration; if it is lower than the
    # current minimum duration or no minimum duration is unset,
    # take the suggested value as duration
    # Duration is the shortest trip (counting only time in the
    # air) from an origin airport to this one, in minutes.
    if (not @duration?) or duration < @duration
      @duration = duration

  @compare: (a, b) =>
    # Compare two airports to determine their order on the
    # y-axis. If the airports belong to the same group,
    # compare them directly, otherwise compare the "minimum"
    # airport in each airport's group.
    if a in b.group
      @directCompare(a, b)
    else
      minA = a.group.sort(Airport.directCompare)[0]
      minB = b.group.sort(Airport.directCompare)[0]
      @directCompare(minA, minB)

  @directCompare: (a, b) ->
    # Compare two airports to determine an order.
    # Rules for comparison are:
    #   - origin airports are always first
    #   - destination airports are always last
    # For connecting airports,
    #   - airports with a shorter minimum duration are first
    #   - if duration is the same, airports with a lower
    #     minimum number of hops (from any origin airport)  are 
    #     first
    if a.type == 'origin' or b.type == 'destination'
      return -1
    else if a.type == 'destination' or b.type == 'origin'
      return 1

    else if a.duration < b.duration
      return -1
    else if a.duration > b.duration
      return 1

    else if a.hops < b.hops
      return -1
    else if a.hops > b.hops
      return 1

    else
      return 0

  # Gate algorithm helper functions
  # The functions getGate, freeGate, and touchGate
  # are helper functions for the gate algorithm.
  # They (and the data they touch) are not useful
  # outside of the gate algorithm.
   
  getGate: ->
    # Get a free gate
    if @freeGates.length == 0
      @freeGates.push(@numGates++)
    return @freeGates.pop()

  freeGate: (gateNumber) ->
    # Free a gate
    @freeGates.push(gateNumber)
    @freeGates.sort((a, b) -> b - a)

  touchGate: ->
    # Get a gate which is free but do
    # not cause the gate to become un-free
    gate = @getGate()
    @freeGate(gate)
    gate

class City
  # Represent a city
  constructor: (@code, @name) ->

class Carrier
  # Represent an airline
  constructor: (@code, @name, @color) ->

class FlightVisualization
  # This class is the workhorse of the visualization.
  # Gathers the data and creates the SVG.

  constructor: (@ita) ->
    # Arguments:
    # ita     the window.ita object which stores all the data
    #         created by the native visualizations

  createSVG: ->
    # Drop the old visualization from the page and create an
    # svg object to contain the new one.
    container = d3.select('#solutionPane td.itaRoundedPaneMain')
    container.select('*').remove()
    container.attr('style', 'height: 600px')
    @svg = container.append('svg:svg')
    @width = @svg[0][0].offsetWidth
    @height = @svg[0][0].offsetHeight
    @svg.append('rect')
        .attr('width', @width)
        .attr('height', @height)
        .style('fill', 'black')

  prepareScales: ->
    # Prepare all d3 scales used for this visualization
    @airportScale = d3.scale.ordinal()
    @airportScale.domain(@airportsList)
    @airportScale.rangeBands([30, @height])

    @dateScale = d3.time.scale()
    @dateScale.domain([@minDeparture, @maxArrival])
    @dateScale.range([50, @width - 20])

    @priceScale = d3.scale.linear()
    @priceScale.domain([@minPrice, @maxPrice])
    @priceScale.range(['#00ff00', '#ff0000'])
    @priceScale.interpolate = d3.interpolateHsl

    @hourScale = d3.scale.linear()
    @hourScale.domain([0, 12, 23])
    @hourScale.range(['#0000dd', '#dddd00', '#0000dd'])
    @priceScale.interpolate = d3.interpolateHsl

  drawYAxis: ->
    # Draw the axis of airport labels
    l = @svg.selectAll('text.yAxis')
          .data(@airportsList)
          .enter()
    l
        .append('text')
        .style('fill', 'white')
        .attr('x', 10)
        .attr('y', @airportScale)
        .style('dominant-baseline', 'middle')
        .style('font-weight', 'bold')
        .text((airport) -> airport)

    l
        .append('text')
        .style('fill', '#aaa')
        .attr('x', 10)
        .attr('y', (x) => @airportScale(x) + 15)
        .style('dominant-baseline', 'middle')
        .text((airport) => @airports[airport].name)

    l
        .append('text')
        .style('fill', '#aaa')
        .attr('x', 10)
        .attr('y', (x) => @airportScale(x) + 30)
        .style('dominant-baseline', 'middle')
        .text((airport) => @airports[airport].city.name)

  drawTimes: ->
    # Draw the time labels and dots
    airportScale = @airportScale
    dateScale = @dateScale
    airports = @airports
    hourScale = @hourScale

    @svg.selectAll('g.timeGroup')
      .data(@airportsList)
      .enter()
      .append('g')
      .each (airportCode) ->
        airport = airports[airportCode]
        g = d3.select(this)
        g.attr('transform', "translate(0, #{airportScale(airportCode)})")

        # Convert a time from UTC to the airport's time zone
        timeToLocal = (time) ->
          moment.utc(time).clone().subtract('minutes', airport.tz)

        # Convert a time to a label
        timeFormat = (time) ->
          timeToLocal(time).format('ha')

        # Convert a time to a color
        timeToColor = (time) ->
          hourScale(timeToLocal(time).hours())

        # Draw the fainter, more plentiful dots
        g.selectAll('circle.y')
          .data(dateScale.ticks(60))
          .enter()
            .append('circle')
            .attr('cx', dateScale)
            .attr('r', 2)
            .style('opacity', 0.3)
            .attr('fill', timeToColor)

        # Draw the darker dots corresponding to labels
        g.selectAll('circle.x')
          .data(dateScale.ticks(20))
          .enter()
            .append('circle')
            .attr('cx', dateScale)
            .attr('r', 2)
            .attr('fill', timeToColor)

        # Draw the labels
        g.selectAll('text')
          .data(dateScale.ticks(20))
          .enter()
            .append('text')
            .attr('x', dateScale)
            .attr('y', -10)
            .attr('text-anchor', 'middle')
            .attr('font-size', '8px')
            .style('dominant-baseline', 'middle')
            .text(timeFormat)
            .attr('fill', timeToColor)

  draw: ->
    # This function drives the entire process of
    # creating the visualization.
    @get_data()
    @createSVG()
    @prepareScales()
    @drawYAxis()
    @drawTimes()

    legPath = (leg) =>
      # Convert a leg into an SVG bezier curve instruction
      # using the scales
      x1 = @dateScale(leg.departure)
      y1 = @airportScale(leg.origin.code) + leg.originGate * 6
      x2 = @dateScale(leg.arrival)
      y2 = @airportScale(leg.destination.code) + leg.destinationGate * 6
      dip = (x2 - x1) * .6
      "M #{x1},#{y1} C #{x1 + dip},#{y1} #{x2 - dip},#{y2} #{x2},#{y2}"

    svg = @svg
    priceScale = @priceScale
    dateScale = @dateScale
    drawDetails = ->
      flight = this.__data__

      d3.select(this).selectAll('path.flight')
        .style('stroke', (leg) -> leg.carrier.color)

      rect = svg.append('rect')
              .attr('class', 'backdrop')
              .attr('x', dateScale(flight.startTime))
              .attr('width', dateScale(flight.endTime) - dateScale(flight.startTime))
              .attr('y', 0)
              .attr('height', 600)
              .style('fill', 'black')
              .style('opacity', 0)
              .transition()
              .style('opacity', 0.8)

      this.parentNode.appendChild(this)

    hideDetails = ->
      flight = this.__data__
      this.parentNode.appendChild(this)

      d3.select(this).selectAll('path.flight')
        .style('stroke', priceScale(flight.price))

      d3.select(this.parentNode).selectAll('rect.backdrop')
        .transition()
        .style('opacity', 0)
        .remove()


    # Plot the flights
    priceScale = @priceScale
    f = @svg.selectAll('g.flight')
        .data(@flights)
        .enter()
          .append('g')
          .on('mouseover', drawDetails)
          .on('mouseout', hideDetails)
          .each (flight) ->
            flightPath = d3.select(this)
                          .selectAll('path')
                          .data((flight) -> flight.legs)
                          .enter()

            flightPath
                .append('path')
                .style('stroke', 'black')
                .style('stroke-width', '7')
                .style('stroke-linecap', 'square')
                .style('fill', 'none')
                .attr('d', legPath)

            flightPath
                .append('path')
                .attr('class', 'flight')
                #.style('stroke', (leg) -> leg.carrier.color)
                .style('stroke', priceScale(flight.price))
                .style('stroke-width', '3')
                .style('stroke-linecap', 'square')
                .style('fill', 'none')
                .attr('d', legPath)

  get_data: ->
    # Gather the data from the ITA models and convert them into our
    # model data structures
    itaData = @ita.flightsPage.flightsPanel.flightList
    carrierToColorMap = @ita.flightsPage.matrix.stopCarrierMatrix.carrierToColorMap
    isoOffsetInMinutes = @ita.isoOffsetInMinutes

    @cities = {}
    @airports = {}
    @flights = []
    @carriers = {}

    # Dummy carrier for time spent at the airport or on ground transit
    # between airports
    @carriers.CONNECTION = new Carrier('CONNECTION', 'Connection', '#eee')

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
      airport = new Airport(code, itaAirport.name, @cities[itaAirport.city],
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
      if not @minPrice? or @minPrice > price
        @minPrice = price
      if not @maxPrice? or @maxPrice < price
        @maxPrice = price
      itaLegs = solution.itinerary.slices[0].legs

      firstLeg = itaLegs[0]
      lastLeg = itaLegs[itaLegs.length - 1]

      # Flight duration
      startTime = moment.utc(firstLeg.departure)
      endTime = moment.utc(lastLeg.arrival)

      lastLeg = null
      duration = 0
      for itaLeg, legIndex in itaLegs
        if lastLeg?
          # Create a dummy leg for the connection
          leg = new Leg(@airports[lastLeg.destination],
                        @airports[itaLeg.origin],
                        moment.utc(lastLeg.arrival),
                        moment.utc(itaLeg.departure),
                        @carriers.CONNECTION)
          leg.setPrevLeg(legs[legs.length-1])
          legs.push(leg)

          # If this connection requires ground transportation,
          # ensure the airports are grouped together in the visualization
          if lastLeg.destination != itaLeg.origin
            @airports[lastLeg.destination].pairWith(@airports[itaLeg.origin])

        airportOrigin = @airports[itaLeg.origin]
        airportDestination = @airports[itaLeg.destination]

        # Set time zones
        airportOrigin.setTz(isoOffsetInMinutes(itaLeg.departure))
        airportDestination.setTz(isoOffsetInMinutes(itaLeg.arrival))

        # Update hops table
        airportOrigin.suggestMinHops(legIndex)
        airportDestination.suggestMinHops(legIndex + 1)

        # Update duration
        airportOrigin.suggestMinDuration(duration)
        duration = duration + itaLeg.duration
        airportDestination.suggestMinDuration(duration)

        # Save leg
        leg = new Leg(airportOrigin,
                      airportDestination,
                      moment.utc(itaLeg.departure),
                      moment.utc(itaLeg.arrival),
                      @carriers[itaLeg.carrier])

        leg.setPrevLeg(legs[legs.length-1])

        legs.push(leg)
        lastLeg = itaLeg

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

    # Figure out minDeparture and maxArrival
    for flight in @flights
      if not @minDeparture? or flight.startTime < @minDeparture
        @minDeparture = flight.startTime
      if not @maxArrival? or flight.endTime > @maxArrival
        @maxArrival = flight.endTime
    console.log @minDeparture, @maxArrival

    # Trim airports
    valid_airports = {}
    for flight in @flights
      for leg in flight.legs
        valid_airports[leg.origin.code] = leg.origin
        valid_airports[leg.destination.code] = leg.destination

    # Create a list of Flight Events, for the gate assigning algorithm
    flightEvents = []
    for flight in @flights
      for leg in flight.legs
        if leg.carrier == @carriers.CONNECTION
          if leg.origin == leg.destination
            flightEvents.push
              flight: flight.index
              event: 'landing'
              time: leg.departure
              airport: leg.origin
              leg: leg
            flightEvents.push
              flight: flight.index
              event: 'takeoff'
              time: leg.arrival
              airport: leg.destination
              leg: leg
          else
            flightEvents.push
              flight: flight.index
              event: 'touch'
              time: leg.departure
              airport: leg.origin
              leg: leg
            flightEvents.push
              flight: flight.index
              event: 'touch'
              time: leg.arrival
              airport: leg.destination
              leg: leg.nextLeg

    flightEvents = flightEvents.sort((a, b) -> a.time - b.time)
    
    # Allocate Gates
    gatesInUse = {}
    for event in flightEvents
      if event.event == 'landing'
        gate = event.airport.getGate()
        gatesInUse[event.flight] = gate
        event.leg.originGate = gate
        event.leg.destinationGate = gate
        event.leg.prevLeg.destinationGate = gate
        event.leg.nextLeg.originGate = gate
      else if event.event == 'takeoff'
        gate = gatesInUse[event.flight]
        airport = event.airport
        airport.freeGate(gate)
      else if event.event == 'touch'
        gate = event.airport.touchGate()
        event.leg.originGate = gate
        event.leg.prevLeg.destinationGate = gate

    # Create a sorted list of airports
    @airportsList = (airport for i, airport of valid_airports).sort(Airport.compare)
    @airportsList = (airport.code for airport in @airportsList)

main = ->
  vis = new FlightVisualization(ita)
  vis.draw()

main()

