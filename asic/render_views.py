# Render beberapa tampilan layout GDS ke PNG dengan KLayout (tanpa GUI).
#
# Di dalam container IIC-OSIC-TOOLS:
#   klayout -zz -r render_views.py -rd gds=<file.gds> -rd out=<folder>
#
# Tampilan:
#   1_chip_metal.png    seluruh chip, met1-met5
#   2_power_grid.png    jaring power (met4, met5)
#   3_routing.png       kabel sinyal (met1-met3)
#   4_pins.png          sudut kanan atas: pin TM1638 di tepi chip
#   5_cells_zoom.png    zoom 25 um: sel standar (diff, poly, li1, met1)
#   6_transistors.png   zoom 8 um: transistor di dalam beberapa sel

import os
import pya

gds = gds  # noqa: F821  (dari -rd gds=...)
out = out  # noqa: F821
lyp = "/foss/pdks/sky130A/libs.tech/klayout/tech/sky130A.lyp"
os.makedirs(out, exist_ok=True)

lv = pya.LayoutView()
lv.set_config("background-color", "#101010")
lv.set_config("grid-visible", "false")
lv.set_config("text-visible", "true")
lv.load_layout(gds, True)
if os.path.exists(lyp):
    lv.load_layer_props(lyp)
lv.max_hier()

cv = lv.active_cellview()
box = cv.cell.dbbox()
W, H = 1600, 1600


def show(layers):
    """layers: daftar (layer, datatype) yang ditampilkan; lainnya disembunyikan."""
    it = lv.begin_layers()
    while not it.at_end():
        p = it.current()
        p.visible = (p.source_layer, p.source_datatype) in layers
        lv.set_layer_properties(it, p)
        it.next()


def save(name, view_box, layers):
    show(layers)
    lv.zoom_box(view_box)
    path = os.path.join(out, name)
    lv.save_image(path, W, H)
    print("ditulis", path)


BOUNDARY = [(235, 4)]
PINS = [(68, 16), (69, 16), (70, 16), (71, 16), (69, 5), (70, 5), (71, 5)]
MET = [(68, 20), (69, 20), (70, 20), (71, 20), (72, 20)]
VIAS = [(68, 44), (69, 44), (70, 44), (71, 44)]
CELL = [(65, 20), (66, 20), (67, 20), (66, 44), (67, 44), (64, 20), (68, 20)]

cx, cy = box.center().x, box.center().y

save("1_chip_metal.png", box, BOUNDARY + MET + PINS)
save("2_power_grid.png", box, BOUNDARY + [(71, 20), (72, 20), (71, 44)])
save("3_routing.png", box, BOUNDARY + [(68, 20), (69, 20), (70, 20)] + PINS)
save("4_pins.png", pya.DBox(box.right - 120, box.top - 120, box.right + 5, box.top + 5),
     BOUNDARY + MET + VIAS + PINS)
save("5_cells_zoom.png", pya.DBox(cx - 12.5, cy - 12.5, cx + 12.5, cy + 12.5), CELL + [(68, 44)])
save("6_transistors.png", pya.DBox(cx - 4, cy - 4, cx + 4, cy + 4),
     [(65, 20), (66, 20), (67, 20), (66, 44), (67, 44), (64, 20)])
