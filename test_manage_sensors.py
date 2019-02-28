import requests
import datetime
import time


class test_sensors():
    URL = "http://localhost:8080/"
    root_eci = "bPAR6SibqLjz6N6U6juad"

    # collection of sensor_id's
    sensors = []
    # collection of ECI's
    picos = []

    def __init__(self):
        self.sensors = [
            "0", "1", "2", "3", "4", "5", "6", "7"
        ]

    def delete_sensor(self, sensor_id):
        url = "{}sky/event/{}/eid/sensor/unneeded_sensor".format(
            self.URL, self.root_eci)
        body = {
            "sensor_id": sensor_id
        }

        r = requests.post(url=url, json=body)

        return r.json()

    def get_temps(self):
        url = "{}sky/cloud/{}/manage_sensors/getTemperatures".format(
            self.URL, self.root_eci)
        r = requests.get(url=url)

        return r.json()

    def get_profile(self, eci):
        url = "{}sky/cloud/{}/sensor_profile/getProfile".format(self.URL, eci)
        r = requests.get(url=url)

        return r.json()

    def get_sensors(self):
        url = "{}sky/cloud/{}/manage_sensors/sensors".format(
            self.URL, self.root_eci)
        r = requests.get(url=url)

        return r.json()

    def add_temperature(self, eci, temp):
        url = "{}sky/event/{}/eid/wovyn/new_temperature_reading".format(
            self.URL, eci)
        body = {
            "temperature": temp,
            "timestamp": str(datetime.datetime.now())
        }
        r = requests.post(url=url, json=body)

        return r.json()

    def create_sensor(self, sensor_id):
        url = "{}sky/event/{}/eid/sensor/new_sensor".format(
            self.URL, self.root_eci)
        body = {
            "sensor_id": sensor_id,
            "name": "Tess",
            "location": "Home",
            "phone": "8018336518"
        }

        r = requests.post(url=url, json=body)

        return r.json()


def create_sensors(test_harness):
    for sensor in test_harness.sensors:
        data = test_harness.create_sensor(sensor)


def delete_sensors(test_harness):
    for sensor in test_harness.sensors:
        data = test_harness.delete_sensor(sensor)


def add_temperatures(test_harness):
    temps = [75, 50, 20, 25, 39, 60]
    picos = test_harness.get_sensors()

    for sensor in picos:
        eci = picos[sensor]

        for temp in temps:
            test_harness.add_temperature(eci, temp)


def test_profiles(test_harness):
    picos = test_harness.get_sensors()

    for sensor in picos:
        eci = picos[sensor]

        profile = test_harness.get_profile(eci)
        print("Sensor: {} PROFILE MATCHES: {}".format(sensor,
                                                      str(profile['name'] == 'Tess' and profile['phone'] == '8018336518' and profile['location'] == 'Home')))

def test_temps(test_harness):
    picos = test_harness.get_sensors()
    temps = [75, 50, 20, 25, 39, 60]

    all_temps = test_harness.get_temps()
    for sensor in picos:
        my_temps = all_temps[sensor]
        print("SENSOR: {}, HAS TEMPS: {}".format(sensor, str(len(my_temps) == len(temps))))



test_harness = test_sensors()

print("Creating Picos")
create_sensors(test_harness)

print("Check Pico-engine online.")
time.sleep(5)

picos = test_harness.get_sensors()

print("Deleting single Pico.")
test_harness.delete_sensor("0")
sensors = test_harness.sensors
updated = test_harness.get_sensors()
print("TEST PICO REMOVED: {}".format(str(len(sensors) != len(updated))))

data = test_harness.add_temperature(picos["0"], 50)
print("TEST PICO DOESN'T EXIST: {}".format(str(data == {
    'error': 'ECI not found: {}'.format(picos["0"])
})))

print("Recreating pico")
test_harness.create_sensor("0")

print("Testing profiles")
test_profiles(test_harness)

print("Adding temperatures")
add_temperatures(test_harness)

print("Testing temperatures")
test_temps(test_harness)

print("Deleting all picos!")
delete_sensors(test_harness)
