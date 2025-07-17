import time
from eye_detection_model import EyeDetectionModel


class PID:
    def __init__(self, kp, ki, kd):
        self.kp = kp
        self.kd = kd
        self.ki = ki
        self.last_time = time.time()
        self.curr_time = None
        self.last_error = 0
        self.integral = 0

    def calculate(self, error):
        self.curr_time = time.time()
        self.dt = self.curr_time - self.last_time
        d_error = (error - self.last_error) / (self.dt)
        self.integral += ((error + self.last_error) * self.dt) / (2)
        self.last_error = error
        self.last_time = self.curr_time
        return self.kp * error + self.ki * self.integral + self.kd * d_error


# kP = 0.001
# kI = 0
# kD = 0.0001 #conservative beginning constants to be tuned


class Plotter:
    def __init__(self, x_pid: PID, y_pid: PID):
        self.eye_model = EyeDetectionModel()
        self.x_pid = x_pid
        self.y_pid = y_pid

    def run(self, debug_display=True):
        try:
            while True:
                # Get eye location from model
                eye_x, eye_y = self.eye_model.get_eye_location(
                    debug_display=debug_display
                )
                if eye_x is not None and eye_y is not None:
                    # Calculate PID outputs
                    x_error = eye_x - self.eye_model.frame_w // 2
                    y_error = eye_y - self.eye_model.frame_h // 2
                    x_output = self.x_pid.calculate(x_error)
                    y_output = self.y_pid.calculate(y_error)
                    print(f"X Output: {x_output}, Y Output: {y_output}")
                else:
                    print("No eye detected")
        except KeyboardInterrupt:
            print("Exiting...")
        finally:
            self.eye_model.cleanup()


def main():
    plotter = Plotter(PID(0.001, 0, 0.0001), PID(0.001, 0, 0.0001))
    plotter.run()


if __name__ == "__main__":
    main()
