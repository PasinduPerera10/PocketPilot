from PIL import Image, ImageDraw
import math

def create_app_icon(size=1024):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size / 2, size / 2
    radius = size / 2 - 8

    # Background circle gradient (dark navy -> mid blue)
    for y in range(size):
        for x in range(size):
            dx, dy = x - cx, y - cy
            dist = math.sqrt(dx * dx + dy * dy)
            if dist <= radius:
                t = (dist / radius)
                r1, g1, b1 = 15, 52, 96       # deep navy
                r2, g2, b2 = 22, 33, 62       # dark blue
                r = int(r1 + (r2 - r1) * t)
                g = int(g1 + (g2 - g1) * t)
                b = int(b1 + (b2 - b1) * t)
                img.putpixel((x, y), (r, g, b, 255))

    # Accent ring (accent color)
    ring_thickness = int(size * 0.06)
    for y in range(size):
        for x in range(size):
            dx, dy = x - cx, y - cy
            dist = math.sqrt(dx * dx + dy * dy)
            if radius - ring_thickness <= dist <= radius:
                t = (dist - (radius - ring_thickness)) / ring_thickness
                r1, g1, b1 = 233, 69, 96
                r2, g2, b2 = 255, 120, 140
                r = int(r1 + (r2 - r1) * t)
                g = int(g1 + (g2 - g1) * t)
                b = int(b1 + (b2 - b1) * t)
                img.putpixel((x, y), (r, g, b, 255))

    draw = ImageDraw.Draw(img)
    # Launch icon shape (stylized abstract flight)
    scale = size * 0.18
    ax, ay = cx, cy - scale * 0.6
    points = [
        (ax, ay),
        (ax + scale * 0.9, ay + scale * 0.9),
        (ax - scale * 0.5, ay + scale * 0.5),
        (ax + scale * 0.1, ay + scale * 1.1),
        (ax - scale * 0.8, ay + scale * 1.2),
        (ax, ay),
    ]
    draw.polygon(points, fill=(255, 255, 255, 255))

    # shadow streak
    streak = [
        (ax - scale * 0.1, ay + scale * 1.1),
        (ax - scale * 0.35, ay + scale * 1.45),
        (ax - scale * 0.22, ay + scale * 1.55),
        (ax + scale * 0.02, ay + scale * 1.2),
    ]
    draw.polygon(streak, fill=(233, 69, 96, 255))

    return img


if __name__ == "__main__":
    out = "pocketpilot_app/assets/app_icon_1024.png"
    icon = create_app_icon(1024)
    icon.save(out, "PNG")
    print(f"Saved {out}")