import pygame
try:
    import RPi.GPIO as GPIO
    has_pi = True
except:
    print('no rpi found')
    has_pi = False
from time import sleep
PWM_PIN=12
RELAY_1_PIN=11
RELAY_2_PIN=13
RELAY_3_PIN=15
RELAY_4_PIN=16

# Define some colors.
BLACK = pygame.Color('black')
WHITE = pygame.Color('white')

def go_forward():
    if has_pi:
        GPIO.output(RELAY_1_PIN, False)
        GPIO.output(RELAY_2_PIN, True)
        GPIO.output(RELAY_3_PIN, True)
        GPIO.output(RELAY_4_PIN, False)
    print(f'going forward, relay 1 True, relay 2 False,relay 3 False,relay 4 True')

def go_backward():
    if has_pi:
        GPIO.output(RELAY_1_PIN, True)
        GPIO.output(RELAY_2_PIN, False)
        GPIO.output(RELAY_3_PIN, False)
        GPIO.output(RELAY_4_PIN, True)
    print(f'going backward, relay 1 False, relay 2 True,relay 3 True,relay 4 False')

def stop_moving():
    if has_pi:
        GPIO.output(RELAY_1_PIN, True)
        GPIO.output(RELAY_2_PIN, True)
        GPIO.output(RELAY_3_PIN, True)
        GPIO.output(RELAY_4_PIN, True)
    print(f'stopping, relay 1 False, relay 2 False,relay 3 False,relay 4 False')




# This is a simple class that will help us print to the screen.
# It has nothing to do with the joysticks, just outputting the
# information.
class TextPrint(object):
    def __init__(self):
        self.reset()
        self.font = pygame.font.Font(None, 20)

    def tprint(self, screen, textString):
        textBitmap = self.font.render(textString, True, BLACK)
        screen.blit(textBitmap, (self.x, self.y))
        self.y += self.line_height

    def reset(self):
        self.x = 10
        self.y = 10
        self.line_height = 15

    def indent(self):
        self.x += 10

    def unindent(self):
        self.x -= 10


def SetAngle(angle):
    if has_pi:
        duty = angle / 18 + 2
        GPIO.output(PWM_PIN, True)
        pwm.ChangeDutyCycle(duty)
        sleep(0.3)
        GPIO.output(PWM_PIN, False)
        pwm.ChangeDutyCycle(0)

def load_img(imgs, name):
    img = pygame.image.load(name + '.png')
    img = pygame.transform.scale(img, (800,480))
    imgs[name] = img

def get_image(mission_flag, mode_flag):
    if mode_flag:
        return mission_flag+'_'+mode_flag
    return mission_flag

pygame.init()

if has_pi:
    GPIO.setmode(GPIO.BOARD)
    GPIO.setup(PWM_PIN, GPIO.OUT)
    GPIO.setup(RELAY_1_PIN, GPIO.OUT)
    GPIO.setup(RELAY_2_PIN, GPIO.OUT)
    GPIO.setup(RELAY_3_PIN, GPIO.OUT)
    GPIO.setup(RELAY_4_PIN, GPIO.OUT)
    stop_moving()
    pwm=GPIO.PWM(PWM_PIN, 50)
    pwm.start(0)
# Set the width and height of the screen (width, height).
screen = pygame.display.set_mode((800, 480))

pygame.display.set_caption("My Game")

# Loop until the user clicks the close button.
done = False

# Used to manage how fast the screen updates.
clock = pygame.time.Clock()
imgs = {}
load_img(imgs, 'idle')
load_img(imgs, 'idle_firefighter')
load_img(imgs, 'idle_ambulance')
load_img(imgs, 'on_mission')
load_img(imgs, 'on_mission_firefighter')
load_img(imgs, 'on_mission_ambulance')

reverse_snd = pygame.mixer.Sound('reverse.wav')
firefighter_snd = pygame.mixer.Sound('firefighter.wav')
ambulance_snd = pygame.mixer.Sound('ambulance.wav')

mission_flag = 'idle'
mode_flag = ''

# Initialize the joysticks.
pygame.joystick.init()

# Get ready to print.
textPrint = TextPrint()
prev_angle = -1
prev_direction = 0
# -------- Main Program Loop -----------
while not done:
    #
    # EVENT PROCESSING STEP
    #
    # Possible joystick actions: JOYAXISMOTION, JOYBALLMOTION, JOYBUTTONDOWN,
    # JOYBUTTONUP, JOYHATMOTION
    for event in pygame.event.get(): # User did something.
        if event.type == pygame.QUIT: # If user clicked close.
            done = True # Flag that we are done so we exit this loop.
        elif event.type == pygame.JOYBUTTONDOWN:
            print("Joystick button pressed.")
        elif event.type == pygame.JOYBUTTONUP:
            print("Joystick button released.")

    #
    # DRAWING STEP
    #
    # First, clear the screen to white. Don't put other drawing commands
    # above this, or they will be erased with this command.
    screen.fill(WHITE)
    textPrint.reset()

    # Get count of joysticks.
    joystick_count = pygame.joystick.get_count()

    textPrint.tprint(screen, "Number of joysticks: {}".format(joystick_count))
    textPrint.indent()

    # For each joystick:
    for i in range(joystick_count):
        joystick = pygame.joystick.Joystick(i)
        joystick.init()

        try:
            jid = joystick.get_instance_id()
        except AttributeError:
            # get_instance_id() is an SDL2 method
            jid = joystick.get_id()
        textPrint.tprint(screen, "Joystick {}".format(jid))
        textPrint.indent()

        # Get the name from the OS for the controller/joystick.
        name = joystick.get_name()
        textPrint.tprint(screen, "Joystick name: {}".format(name))

        try:
            guid = joystick.get_guid()
        except AttributeError:
            # get_guid() is an SDL2 method
            pass
        else:
            textPrint.tprint(screen, "GUID: {}".format(guid))

        # Usually axis run in pairs, up/down for one, and left/right for
        # the other.
        axes = joystick.get_numaxes()
        textPrint.tprint(screen, "Number of axes: {}".format(axes))
        textPrint.indent()

        for i in range(axes):
            axis = joystick.get_axis(i)
            textPrint.tprint(screen, "Axis {} value: {:>6.3f}".format(i, axis))
        textPrint.unindent()

        buttons = joystick.get_numbuttons()
        textPrint.tprint(screen, "Number of buttons: {}".format(buttons))
        textPrint.indent()

        for i in range(buttons):
            button = joystick.get_button(i)
            textPrint.tprint(screen,
                             "Button {:>2} value: {}".format(i, button))
        mode_flag = ''
        if joystick.get_button(4):
            mode_flag = 'firefighter'
        if joystick.get_button(5):
            mode_flag = 'ambulance'

        textPrint.unindent()

        hats = joystick.get_numhats()
        textPrint.tprint(screen, "Number of hats: {}".format(hats))
        textPrint.indent()

        # Hat position. All or nothing for direction, not a float like
        # get_axis(). Position is a tuple of int values (x, y).
        for i in range(hats):
            hat = joystick.get_hat(i)
            textPrint.tprint(screen, "Hat {} value: {}".format(i, str(hat)))
        textPrint.unindent()

        textPrint.unindent()
        joy_x = joystick.get_axis(0)
        if joy_x < -0.5:
            if prev_angle != -0.5:
                SetAngle(0)
                prev_angle = -0.5
        elif joy_x < 0.5:
            if prev_angle != 0:
                SetAngle(45)
                prev_angle = -0
        else:
            if prev_angle != 0.5:
                SetAngle(90)
                prev_angle = 0.5

        joy_y = joystick.get_axis(1)
        if joy_y < -0.5:
            if prev_direction != -0.5:
                go_backward()
                #GPIO.output(RELAY_1_PIN, False)
                #print(f'pin {RELAY_1_PIN} off')
                prev_direction = -0.5
                mission_flag = 'on_mission'
                if mode_flag == 'firefighter':
                    firefighter_snd.play()
                elif mode_flag == 'ambulance':
                    ambulance_snd.play()
                reverse_snd.stop()
        elif joy_y < 0.5:
            if prev_direction != 0:
                stop_moving()
                #GPIO.output(RELAY_1_PIN, False)
                #print(f'pin {RELAY_1_PIN} off')
                prev_direction = 0
                mission_flag = 'idle'
                firefighter_snd.stop()
                ambulance_snd.stop()
                reverse_snd.stop()
        else:
            if prev_direction != 0.5:
                go_forward()
                #GPIO.output(RELAY_1_PIN, True)
                #print(f'pin {RELAY_1_PIN} on')
                prev_direction = 0.5
                mission_flag = 'idle'
                firefighter_snd.stop()
                ambulance_snd.stop()
                reverse_snd.play(loops=10)
        #SetAngle(180 + joystick.get_axs(0) * 180)

    screen.blit(imgs[get_image(mission_flag, mode_flag)], (50, 50))
    #
    # ALL CODE TO DRAW SHOULD GO ABOVE THIS COMMENT
    #

    # Go ahead and update the screen with what we've drawn.
    pygame.display.flip()

    # Limit to 20 frames per second.
    clock.tick(20)

# Close the window and quit.
# If you forget this line, the program will 'hang'
# on exit if running from IDLE.
pwm.stop()
if has_pi:
    GPIO.cleanup()
pygame.quit()
