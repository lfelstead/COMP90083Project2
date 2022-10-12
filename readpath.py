import csv
import numpy as np

# reads dove lake gps data obtained from: https://www.alltrails.com/trail/australia/tasmania/dove-lake-circuit
# outputs file which can be read into NetLogo containing the coordinates of the trail

coordinates = []
with open('Dove Lake Circuit.csv', newline='') as csvfile:
    for r in csvfile.readlines():
        coordinates.append(r[:-2].split(","))
coordinates = np.array(coordinates[1:], dtype=float)
print(coordinates[:,0])
print(np.min(coordinates[:,0]),np.max(coordinates[:,0]) )
print(np.min(coordinates[:,1]),np.max(coordinates[:,1]) )
print(len(coordinates[:,0]))
latmean, longmean, altmean = np.mean(coordinates, axis=0)

# need to experiment to determine how many decimal places to keep 
lat = np.round((coordinates[:,0] -latmean)*10000)
lon = np.round((coordinates[:,1] -longmean)*10000)

print(np.min(lat),np.max(lat) )
print(np.min(lon),np.max(lon) )

path = ""
for x in range(len(lat)):
    path += str(lat[x]) + " " + str(lon[x] ) + " 5 " # 5 is gray in netlogo

with open('dovelake.txt', 'w') as f:
    print(path, file=f)  