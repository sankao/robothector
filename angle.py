import time
try:
    import RPi.GPIO as GPIO
    has_pi = True
except:
    print('no rpi found')
    has_pi = False
from time import sleep
PWM_PIN=12

def SetAngle(angle):
    if has_pi:
        duty = angle / 18 + 2
        GPIO.output(PWM_PIN, True)
        pwm.ChangeDutyCycle(duty)
        sleep(0.3)
        GPIO.output(PWM_PIN, False)
        pwm.ChangeDutyCycle(0)

if has_pi:
    GPIO.setmode(GPIO.BOARD)
    GPIO.setup(PWM_PIN, GPIO.OUT)
    pwm=GPIO.PWM(PWM_PIN, 50)
    pwm.start(0)


for i in range(25, 125, 5):
    duty = 0.1 * i
    print(f'setting duty cycle {duty}')
    if has_pi:
        GPIO.output(PWM_PIN, True)
        pwm.ChangeDutyCycle(duty)
    sleep(2)
    if has_pi:
        GPIO.output(PWM_PIN, False)
        pwm.ChangeDutyCycle(0)
    print(f'setting duty cycle {0}')
    time.sleep(2)

if has_pi:
    GPIO.cleanup()
