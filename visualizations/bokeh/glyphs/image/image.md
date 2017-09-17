
# Bokeh Image Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from bokeh.models.mappers import ColorMapper
import numpy as np

line_color = '#1f78b4'
fill_color = 'black'
output_file("../../figures/glyph-image.html")

N = 1024
nc = N//2
xx, yy = np.meshgrid(np.arange(N)-nc, np.arange(N)-nc)
img = np.sqrt(xx**2 + yy**2)
p = figure(plot_width=400, plot_height=400)
p.image(x=-nc, y=-nc, image=[img], dw=N, dh=N, palette="Spectral11")
p.x_range = Range1d(-nc, nc, bounds=(-nc, nc))
p.y_range = Range1d(-nc, nc, bounds=(-nc, nc))
show(p)
```
