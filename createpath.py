path = ""
for x in range (-10, 11):
    for y in range (-10, 11):
        if (x ==0 and y > 5) or ((y == 5 or y == -5 ) and x > -8 and x < 8) or ((x == 7 or x == -7 ) and y > -5 and y < 5):
            path += str(x) + " " + str(y) + " 5 " # 5 is gray in netlogo
        else:
            path += str(x) + " " + str(y) + " 55 " # 55 is green in netlogo

with open('squarepath.txt', 'w') as f:
    print(path, file=f)  

