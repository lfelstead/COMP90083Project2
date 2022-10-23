import csv
import numpy as np

# reads dove lake gps data obtained from: 
#   https://www.alltrails.com/trail/australia/tasmania/dove-lake-circuit
#   https://www.alltrails.com/explore/map/dove-lake-circuit-cradle-mountain-and-overland-track-6e82873

# outputs file which can be read into NetLogo containing the coordinates of the trail

# read in track data
coordinates = []
with open('Cradle Summit and Hansons Peak via Overland Track and Face Track.csv', newline='') as csvfile:
    for r in csvfile.readlines()[1:]:
        coordinates.append(r[:-2].split(","))

coordinates = np.array(coordinates, dtype=float)
latmean, longmean, altmean = np.mean(coordinates, axis=0)

# normalise coorindates to match netlogo orientation
latoffset, lonoffset = 30, 25 # need to center tracks in netlogo
lat = np.round((coordinates[:,0] -latmean)*-10000)+latoffset 
lon = np.round((coordinates[:,1] -longmean)*10000)-lontoffset


# calculate distance between two coorindates
def calculate_distance(lat1, lon1, lat2, lon2): return max(abs(lat1-lat2),abs(lon1-lon2))

# get closest positive and negative point
def getbetweenpoints(lat1, lon1, lat2, lon2, points):
    if lat1 == lat2 and lon1 == lon2: return points
    if lat1 < lat2: lat1 += 1
    elif lat1 > lat2: lat1 -= 1

    if lon1 < lon2: lon1 += 1
    elif lon1 > lon2: lon1 -= 1

    points.append((lat1, lon1))
    return getbetweenpoints(lat1, lon1, lat2, lon2, points)

# find the closest neighbouring coordinate to lat lon point
# generate points between lat lon and neighbour
def fillgaps(lat, lon, alllat, alllon, mindist):
    newlat, newlon = [],[]
    closestup = [-1, -1, 15 ] # [lat, lon, dist]
    closestdown = [-1, -1, 15 ] # [lat, lon, dist]
    for x in range(len(alllat)):
        dist = calculate_distance(lat, lon, alllat[x], alllon[x])

        if dist > mindist and lon >= alllon[x] and dist < closestup[2]: closestup = [alllat[x], alllon[x], dist]
        elif dist > mindist and lon <= alllon[x] and dist < closestdown[2]: closestdown = [alllat[x], alllon[x], dist]

    # connected to at least one other point (assumed circuit)
    points = []
    if closestup[0] != -1:  points += getbetweenpoints(lat, lon, closestup[0], closestup[1], []) 
    if closestdown[0] != -1:  points += getbetweenpoints(lat, lon, closestdown[0], closestdown[1], []) 
    for x,y in points:
        newlat=np.append(newlat,x)
        newlon=np.append(newlon,y)
    return newlat, newlon

# generates points inbetween to fill gaps
newlat, newlon = np.copy(lat), np.copy(lon)
for x in range(len(lat)):
    x, y = fillgaps(lat[x], lon[x], lat, lon, 1)
    newlat=np.append(newlat,x)
    newlon=np.append(newlon,y)

# format coordinates for netlogo
path = ""
for x in range(newlat.size):
    path += str(newlat[x]) + " " + str(newlon[x] ) + " 5 " # 5 is gray in netlogo

# read in lake data (coordinates of the perimeter of the lake)
coordinates1 = []
with open('Lakes.csv', newline='') as csvfile:
    for r in csvfile.readlines():
        coordinates1.append(r[:-2].split(","))
coordinates1 = np.array(coordinates1[1:], dtype=float)


# repeat normalising step so lakes and track data matches
lat = np.round((coordinates1[:,0] -latmean)*-10000)+latoffset
lon = np.round((coordinates1[:,1] -longmean)*10000)-lontoffset

# fill gaps between neighbour points
newlat, newlon = np.copy(lat), np.copy(lon)
for x in range(len(lat)):
    x, y = fillgaps(lat[x], lon[x], lat, lon, 5)
    newlat=np.append(newlat,x)
    newlon=np.append(newlon,y)

import queue

# bucket fill to generate lake points inside lake perimeter
def queuefill(x,y, coordinates):
    q = queue.Queue()
    coordinates.add((x,y))
    q.put((x,y))

    while not q.empty() and q.qsize() < 100000:
        x,y = q.get()

        if (x+1, y) not in coordinates: 
            coordinates.add((x+1,y))
            q.put((x+1, y))
        if (x, y+1) not in coordinates: 
            coordinates.add((x,y+1))
            q.put((x, y+1))
        if (x-1, y) not in coordinates: 
            coordinates.add((x-1,y))
            q.put((x-1, y))
        if (x, y-1) not in coordinates: 
            coordinates.add((x,y-1))
            q.put((x, y-1))

        print("queue size:", q.qsize())

    return coordinates



# starting bucket fill from point inside lake perimeter
coordinates = queuefill(-29, 49,set(zip(newlat, newlon)))
coordinates = queuefill(-90, -12, coordinates)
coordinates = queuefill(119, -8, coordinates)
coordinates = queuefill(-113, -60, coordinates)
coordinates = queuefill(-21, -120, coordinates)

# format output for netlogo
for x,y in coordinates:
    path = str(x) + " " + str(y ) + " 95 " + path # 95 is gray in netlogo

# output track and lake data to file
with open('alltracks.txt', 'w') as f:
    print(path, file=f)  


# read altitude data 
altdata = []
with open('elevation.csv', newline='') as csvfile:
    for r in csvfile.readlines()[1:]:
        altdata.append(r[:-2].split(","))
altdata = np.array(altdata, dtype=float)

# repeat normalising steps to match with lake and track data
lat = np.round((altdata[:,0] -latmean)*-10000)+latoffset
lon = np.round((altdata[:,1] -longmean)*10000)-lontoffset
elevation = altdata[:,2]


output = ""
for x,y,e in set(zip(lat, lon,elevation)):
    # only keep points that are inside the netlogo display 
    if x > -260 and x <260 and y > -140 and y < 140:
        output += str(x) + " " + str(y) + " " + str(e) + " "

with open('elevation.txt', 'w') as f:
    print(output, file=f)  
