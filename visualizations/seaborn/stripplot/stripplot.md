
# seaborn.stripplot
---
A strip plot is a scatter plot where one of the variables is categorical. They can be combined with other plots to provide additional information. For example, a boxplot with an overlaid strip plot becomes more similar to a violin plot because some additional information about how the underlying data is distributed becomes visible.

dataset:


```python
%matplotlib inline
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
plt.rcParams['figure.figsize'] = (20.0, 10.0)
plt.rcParams['font.family'] = "serif"
```


```python
from sklearn import datasets
iris_data = datasets.load_iris()
```


```python
iris_data['feature_names']
```




    ['sepal length (cm)',
     'sepal width (cm)',
     'petal length (cm)',
     'petal width (cm)']




```python
df = pd.DataFrame(data=np.column_stack([iris_data['data'],iris_data['target']]),
                  columns=['Sepal Length (cm)',
                           'Sepal Width (cm)',
                           'Petal Length (cm)',
                           'Petal Width (cm)',
                           'Species'])
```


```python
df['Species'] = iris_data['target_names'][df.Species.astype(int)]
```

Basic plot


```python
p = sns.stripplot(data=df, x='Species', y='Sepal Length (cm)')
```


![png](output_7_0.png)


Change the `order` in which the names are displayed


```python
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  order=sorted(df.Species.unique(), reverse=True))
```


![png](output_9_0.png)


`jitter` can be used to randomly provide displacements along the horizontal axis, which is useful when there are large clusters of datapoints


```python
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1)
```


![png](output_11_0.png)


To help illustrate some of the other properties, I'll randomly assign a label "Day" or "Night" to all the flowers.


```python
df['Measurement Time'] = 'Night'
df.loc[np.random.rand(len(df)) > 0.5, 'Measurement Time'] = 'Day'
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  hue='Measurement Time',
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1)
```


![png](output_13_0.png)


We see the default behavior is to stack the different hues on top of each other. This can be avoided with `dodge` (formerly called `split`)


```python
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  hue='Measurement Time',
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1,
                  dodge=True)
```


![png](output_15_0.png)


Flipping x and y inputs and setting `orient` to 'h' can be used to make a horizontal plot


```python
p = sns.stripplot(data=df,
                  y='Species',
                  x='Sepal Length (cm)',
                  hue='Measurement Time',
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1,
                  dodge=False,
                  orient='h')
```


![png](output_17_0.png)


For coloring, you can either provide a single color to `color`...


```python
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  hue='Measurement Time',
                  color=(.25,.5,.75),
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1,
                  dodge=False)
```


![png](output_19_0.png)


...or you can use one of the many variations of the `palette` parameter


```python
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  hue='Measurement Time',
                  palette=sns.husl_palette(2, l=0.5, s=.95),
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1,
                  dodge=False)
```


![png](output_21_0.png)


Adjust the marker `size`


```python
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  hue='Measurement Time',
                  palette=sns.husl_palette(2, l=0.5, s=.95),
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1,
                  dodge=False,
                  size=20)
```


![png](output_23_0.png)


Adjust the `linewidth` of the edges of the circles


```python
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  hue='Measurement Time',
                  palette=sns.husl_palette(2, l=0.5, s=.95),
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1,
                  dodge=False,
                  size=20,
                  linewidth=3)
```


![png](output_25_0.png)


Change the color of these lines with `edgecolor`


```python
p = sns.stripplot(data=df,
                  x='Species',
                  y='Sepal Length (cm)',
                  hue='Measurement Time',
                  palette=sns.husl_palette(2, l=0.5, s=.95),
                  order=sorted(df.Species.unique(), reverse=True),
                  jitter=0.1,
                  dodge=False,
                  size=20,
                  edgecolor='blue',
                  linewidth=3)
```


![png](output_27_0.png)


Swarmplots look good when overlaid on top of another categorical plot, like `boxplot`


```python
params = dict(data=df,
              x='Species',
              y='Sepal Length (cm)',
              hue='Measurement Time',
              order=sorted(df.Species.unique(), reverse=True),
              dodge=True)
p = sns.stripplot(size=14,
                  jitter=0.25,
                  palette=['#fc8d59','#91bfdb'],
                  edgecolor='black',
                  linewidth=3,
                  **params)
p_box = sns.boxplot(palette=['#BBBBBB','#DDDDDD'],**params)
```


![png](output_29_0.png)


Finalize


```python
plt.rcParams['font.size'] = 30
df.Species = df.Species.apply(lambda x: x.capitalize())
params = dict(data=df,
              x='Species',
              y='Sepal Length (cm)',
              hue='Measurement Time',
              order=sorted(df.Species.unique(), reverse=True),
              dodge=True)
p = sns.stripplot(size=14,
                  jitter=0.25,
                  palette=['#fc8d59','#91bfdb'],
                  edgecolor='black',
                  linewidth=3,
                  **params)
p_box = sns.boxplot(palette=['#BBBBBB','#DDDDDD'],**params)
handles,labels = p.get_legend_handles_labels()
#for h in handles:
#    h.set_height(3)
#handles[2].set_linewidth(33)
for l in labels:
    #l.title = "hey"
    print(l)
plt.legend(handles[2:],
           labels[2:],
           bbox_to_anchor=(.65,.45),
           fontsize = 40,
           markerscale=5,
           frameon=False,
           labelspacing=0.2)
plt.text(0.85,7.5, "Strip Plot", fontsize = 95, color='Black', fontstyle='italic')
plt.xlabel('')
p
```

    Night
    Day
    Night
    Day





    <matplotlib.axes._subplots.AxesSubplot at 0x10e76c198>




![png](output_31_2.png)



```python
p.get_figure().savefig('../../figures/stripplot.png')
```
