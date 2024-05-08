Based on the code by Anton Mendvedev, found at https://github.com/antonmdv/Morphing/blob/master/morphing.py

from PIL import Image
import numpy as np
import imageio
import random


def generateRegularGridPoints(image_shape, grid_size, max_offset):
    """
    Generate regular grid control points across the image with random integer offsets.

    Args:
    - image_shape (tuple): Shape of the image (height, width).
    - grid_size (int): Size of the grid (number of points along each axis).
    - max_offset (int): Maximum integer offset to add to each grid point.

    Returns:
    - points (list): List of control points [(x1, y1), (x2, y2), ...].
    """

    height, width = image_shape
    step_x = width // (grid_size + 1)
    step_y = height // (grid_size + 1)

    points = []
    for i in range(1, grid_size + 1):
        for j in range(1, grid_size + 1):
            x_offset = random.randint(-max_offset, max_offset)
            y_offset = random.randint(-max_offset, max_offset)
            x = min(max(i * step_x + x_offset, 0), width)
            y = min(max(j * step_y + y_offset, 0), height)
            points.append((x, y))

    return points

# Util function for perpendicular vector
def perpendicular(vector):
    return np.array([-vector[1], vector[0]])


def calculate_displacement(pixel, interpolated_p, interpolated_q, src_p, dest_p, src_q, dest_q, a, b, m):
    """
    Calculates the displacement vectors and weight sum for a given pixel.

    Args:
    - pixel (numpy.ndarray): Coordinates of the pixel.
    - interpolated_p (numpy.ndarray): Interpolated control points for image 1.
    - interpolated_q (numpy.ndarray): Interpolated control points for image 2.
    - src_p (list): Source control points for image 1.
    - dest_p (list): Destination control points for image 1.
    - src_q (list): Source control points for image 2.
    - dest_q (list): Destination control points for image 2.
    - a (float): Constant for line equation.
    - b (float): Constant for line equation.
    - m (float): Constant for line equation.

    Returns:
    - displacement_1 (numpy.ndarray): Displacement vector for image 1.
    - displacement_2 (numpy.ndarray): Displacement vector for image 2.
    - weight_sum (float): Sum of weights for the pixel.
    """

    # Calculate displacement vectors and weight sum
    displacement_1 = np.zeros(2)
    displacement_2 = np.zeros(2)
    weighted_displacement_1 = np.zeros(2)
    weighted_displacement_2 = np.zeros(2)
    weight_sum = 0

    for i in range(len(src_p)):
        P = interpolated_p[i]
        Q = interpolated_q[i]
        P1, P2 = src_p[i], dest_p[i]
        Q1, Q2 = src_q[i], dest_q[i]

        delta_pixel_P = pixel - P
        delta_pixel_Q = pixel - Q
        delta_Q_P = Q - P
        norm_Q_P = np.linalg.norm(delta_Q_P)
        delta_Q1_P1 = Q1 - P1
        delta_Q2_P2 = Q2 - P2
        
        U = (delta_pixel_P @ delta_Q_P) / (norm_Q_P ** 2)
        V = (delta_pixel_P @ perpendicular(delta_Q_P)) / norm_Q_P

        x_prime_1 = P1 + U * delta_Q1_P1 + V * perpendicular(delta_Q1_P1) / np.linalg.norm(delta_Q1_P1)
        x_prime_2 = P2 + U * delta_Q2_P2 + V * perpendicular(delta_Q2_P2) / np.linalg.norm(delta_Q2_P2)

        displacement_1 += x_prime_1 - pixel
        displacement_2 += x_prime_2 - pixel

        if U >= 1:
            shortest_dist = np.linalg.norm(delta_pixel_Q)
        elif U <= 0:
            shortest_dist = np.linalg.norm(delta_pixel_P)
        else:
            shortest_dist = abs(V)

        line_weight = ((norm_Q_P ** m) / (a + shortest_dist)) ** b
        
        weighted_displacement_1 += line_weight * displacement_1
        weighted_displacement_2 += line_weight * displacement_2

        weight_sum += line_weight

    return displacement_1, displacement_2, weighted_displacement_1, weighted_displacement_2, weight_sum

def morph_frame(im1, im2, each_frame, src_p, src_q, dest_p, dest_q, a, b, m, height, width, num_morphed_frames):
    """
    Morphs a frame of the images im1 and im2 using the given control points.

    Args:
    - im1 (PIL.Image): First input image.
    - im2 (PIL.Image): Second input image.
    - each_frame (int): Current frame number.
    - src_p (list): Source control points for image 1.
    - src_q (list): Source control points for image 2.
    - dest_p (list): Destination control points for image 1.
    - dest_q (list): Destination control points for image 2.
    - a (float): Constant for line equation.
    - b (float): Constant for line equation.
    - m (float): Constant for line equation.
    - width (int): Width of the images.
    - height (int): Height of the images.
    - num_morphed_frames (int): Total number of frames to generate.
    """

    # Create a blank image for the morphed frame
    morphed_im = Image.new("RGB", (width, height), "white")

    # Calculate the interpolated control points for the current frame
    interpolated_p = src_p + (dest_p - src_p) / (num_morphed_frames + 1) * (each_frame + 1)
    interpolated_q = src_q + (dest_q - src_q) / (num_morphed_frames + 1) * (each_frame + 1)

    # Iterate over each pixel in the output image
    for w in range(width):
        for h in range(height):
            pixel = np.array([w, h])
            displacement_1, displacement_2, weighted_displacement_1, weighted_displacement_2, weight_sum = calculate_displacement(pixel, interpolated_p, interpolated_q, src_p, dest_p, src_q, dest_q, a, b, m)

            x_prime1 = pixel + weighted_displacement_1 / weight_sum
            x_prime2 = pixel + weighted_displacement_2 / weight_sum

            src_x = int(x_prime1[0])
            src_y = int(x_prime1[1])
            dest_x = int(x_prime2[0])
            dest_y = int(x_prime2[1])

            src_RGB = im1.getpixel((src_x, src_y)) if 0 <= src_x < width and 0 <= src_y < height else im1.getpixel((w, h))
            dest_RGB = im2.getpixel((dest_x, dest_y)) if 0 <= dest_x < width and 0 <= dest_y < height else im2.getpixel((w, h))

            wI2 = float(2 * (each_frame + 1) * (1 / (num_morphed_frames + 1)))
            wI1 = float(2 - wI2)

            R = (wI1 * src_RGB[0] + wI2 * dest_RGB[0]) / 2
            G = (wI1 * src_RGB[1] + wI2 * dest_RGB[1]) / 2
            B = (wI1 * src_RGB[2] + wI2 * dest_RGB[2]) / 2

            morphed_im.putpixel((w, h), (int(R), int(G), int(B)))

    imageio.imwrite(f'morph_p_{each_frame + 1}.jpg', morphed_im)
    print(f'Image {each_frame + 1} was saved')