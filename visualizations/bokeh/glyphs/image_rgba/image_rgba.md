
# Bokeh Image RGBA Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from bokeh.models.mappers import ColorMapper
import numpy as np
from bokeh.io import export_png

line_color = '#1f78b4'
fill_color = 'black'
output_file("../../figures/image_rgba.html")

N = 20
nc = N//2
xx, yy = np.meshgrid(np.arange(N), np.arange(N))
r = np.sqrt(xx**2 + yy**2)
r /= np.max(r)
img = np.zeros((N, N, 4),dtype=np.uint8)
img[:, :, 0] = (r*40).astype(np.uint8) 
img[:, :, 1] = (r*200).astype(np.uint8) 
img[:, :, 2] = (r*200).astype(np.uint8) 
img[:, :, 3] = 255
p = figure(plot_width=400, plot_height=400)
p.image_rgba(x=[0], y=[0], image=[img], dw=[N], dh=[N])
p.x_range = Range1d(0, N, bounds=(0, N))
p.y_range = Range1d(0, N, bounds=(0, N))
show(p)
export_png(p, filename="../../figures/image_rgba.png");
```
