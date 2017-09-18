
# Bokeh Text Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d, ColumnDataSource
from bokeh.io import export_png
from math import pi
import numpy as np
import matplotlib.cm as cm
import pandas as pd
import string

output_file("../../figures/text.html")
num_lines = 24
df = pd.DataFrame(dict(
x0 = [0.5]*num_lines,
y0 = [0.5]*num_lines,
text_font_size = '16pt',
text = [letter for letter in string.ascii_letters[:num_lines]],
length = np.linspace(0.1,0.9,num_lines),
angle = np.linspace(0,4*pi,num_lines, endpoint=False)
))

df['x1'] = df['x0'] + df['length'] * np.cos(df['angle'])
df['y1'] = df['y0'] + df['length'] * np.sin(df['angle'])

cmap = cm.get_cmap('inferno')
df['colors'] = ["#%02x%02x%02x" % (int(r), int(g), int(b)) for r, g, b, a in 255*cmap(df['length'])]
source = ColumnDataSource(df) 

p = figure(plot_width=400, plot_height=400)
p.text(x='x1', y='y1', text='text', source=source, angle='angle', text_font_size="14pt")
p.x_range = Range1d(-0.75, 1.75, bounds=(-1,2))
p.y_range = Range1d(-0.75, 1.75, bounds=(-1,2))
show(p)
export_png(p, filename="../../figures/text.png");
```
