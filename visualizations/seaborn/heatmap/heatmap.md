
# seaborn.heatmap
---
Heat maps display numeric tabular data where the cells are colored depending upon the contained value. Heat maps are great for making trends in this kind of data more readily apparent, particularly when the data is ordered and there is clustering.

dataset: [Seaborn - flights](https://github.com/mwaskom/seaborn-data/blob/master/flights.csv)


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
df = pd.pivot_table(data=sns.load_dataset("flights"),
                    index='month',
                    values='passengers',
                    columns='year')
df.head()
```




<div>
<style>
    .dataframe thead tr:only-child th {
        text-align: right;
    }

    .dataframe thead th {
        text-align: left;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }
</style>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th>year</th>
      <th>1949</th>
      <th>1950</th>
      <th>1951</th>
      <th>1952</th>
      <th>1953</th>
      <th>1954</th>
      <th>1955</th>
      <th>1956</th>
      <th>1957</th>
      <th>1958</th>
      <th>1959</th>
      <th>1960</th>
    </tr>
    <tr>
      <th>month</th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>January</th>
      <td>112</td>
      <td>115</td>
      <td>145</td>
      <td>171</td>
      <td>196</td>
      <td>204</td>
      <td>242</td>
      <td>284</td>
      <td>315</td>
      <td>340</td>
      <td>360</td>
      <td>417</td>
    </tr>
    <tr>
      <th>February</th>
      <td>118</td>
      <td>126</td>
      <td>150</td>
      <td>180</td>
      <td>196</td>
      <td>188</td>
      <td>233</td>
      <td>277</td>
      <td>301</td>
      <td>318</td>
      <td>342</td>
      <td>391</td>
    </tr>
    <tr>
      <th>March</th>
      <td>132</td>
      <td>141</td>
      <td>178</td>
      <td>193</td>
      <td>236</td>
      <td>235</td>
      <td>267</td>
      <td>317</td>
      <td>356</td>
      <td>362</td>
      <td>406</td>
      <td>419</td>
    </tr>
    <tr>
      <th>April</th>
      <td>129</td>
      <td>135</td>
      <td>163</td>
      <td>181</td>
      <td>235</td>
      <td>227</td>
      <td>269</td>
      <td>313</td>
      <td>348</td>
      <td>348</td>
      <td>396</td>
      <td>461</td>
    </tr>
    <tr>
      <th>May</th>
      <td>121</td>
      <td>125</td>
      <td>172</td>
      <td>183</td>
      <td>229</td>
      <td>234</td>
      <td>270</td>
      <td>318</td>
      <td>355</td>
      <td>363</td>
      <td>420</td>
      <td>472</td>
    </tr>
  </tbody>
</table>
</div>



Default plot


```python
sns.heatmap(df)
```




    <matplotlib.axes._subplots.AxesSubplot at 0x10efafdd8>




![png](output_4_1.png)


`cmap` adjusts the colormap used. I like diverging colormaps for heatmaps because they provide good contrast.


```python
sns.heatmap(df, cmap='coolwarm')
```




    <matplotlib.axes._subplots.AxesSubplot at 0x10f0e1eb8>




![png](output_6_1.png)


`center` can be used to indicate at which numeric value to use the center of the colormap. Above we see most of the map using blues, so by setting the value of `center` equal to the midpoint of the data then we can create a map where there are more equal amounts of red and blue shades.


```python
midpoint = (df.values.max() - df.values.min()) / 2
sns.heatmap(df, cmap='coolwarm', center=midpoint)
```




    <matplotlib.axes._subplots.AxesSubplot at 0x10fec2048>




![png](output_8_1.png)


Adjust the lower and upper contrast bounds with `vmin` and `vmax`. Everything below `vmin` will be the same color. Likewise for above `vmax`.


```python
midpoint = (df.values.max() - df.values.min()) / 2
sns.heatmap(df, cmap='coolwarm', center=midpoint, vmin=150, vmax=400)
```




    <matplotlib.axes._subplots.AxesSubplot at 0x1104a0e80>




![png](output_10_1.png)

Alternatively, you can set `vmin` and `vmax` to lie outside of the range of the data for a more muted, washed-out look

```python
midpoint = (df.values.max() - df.values.min()) / 2
sns.heatmap(df, cmap='coolwarm', center=midpoint, vmin=-100, vmax=800)
```




    <matplotlib.axes._subplots.AxesSubplot at 0x110aac6d8>




![png](output_12_1.png)





```python
midpoint = (df.values.max() - df.values.min()) / 2
p = sns.heatmap(df, cmap='coolwarm', center=midpoint)
```


![png](output_14_0.png)





```python
p.get_figure().savefig('../../figures/heatmap.png')
```




```python

```




```python

```




```python

```




```python

```




```python

```




```python
 flights_long.pivot(index="month", columns="year", values='passengers')


```


    ---------------------------------------------------------------------------

    NameError                                 Traceback (most recent call last)

    <ipython-input-10-ed58a0e1a61a> in <module>()
    ----> 1 flights_long.pivot(index="month", columns="year", values='passengers')
          2 


    NameError: name 'flights_long' is not defined



```python

```


```python

```


```python

```


```python

```


```python

```


```python

```


```python

```


```python

```


```python

```
