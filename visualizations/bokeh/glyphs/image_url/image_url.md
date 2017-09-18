
# Bokeh Image URL Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d, ColumnDataSource
from bokeh.models.mappers import ColorMapper
import numpy as np
from bokeh.io import export_png
p = figure(plot_width=400, plot_height=400)
N = 5
line_color = '#1f78b4'
fill_color = 'black'
output_file("../../figures/image_url.html")

url = 'https://github.com/prism-em/prism-em.github.io/raw/master/img/PRISM_transparent_512.png'
N = 12
source = ColumnDataSource(dict(
    url = [url]*N,
    x1  = 64*np.arange(N),
    y1  = np.arange(N)*64 + np.random.rand(N)*32,
    w1  = [64]*N,
    h1  = [64]*N,
))
p.image_url(url='url' ,x='x1', y='y1', w='w1', h='h1',source=source, anchor="center")

p.x_range = Range1d(-10, 10+32*N)
p.y_range = Range1d(10, 10+32*N)
show(p)
export_png(p, filename="../../figures/image_url.png");
```
