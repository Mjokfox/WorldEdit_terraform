# WorldEdit terraform

A terraforming/smoothing command for [minetest-WorldEdit](https://github.com/Uberi/Minetest-WorldEdit)

## usage
//terraform \<radius\> \<threshold\> \<shape\>

radius: Radius of the terraform operation (0 to radius_limit).\
threshold: Threshold value for the operation (0 to 100).\
shape: Shape of the terraform area, either "sphere" or "cube".
    

## Settings

radius_limit: Maximum allowable radius for the terraform operation.\
threshold_multiplier: Multiplier applied to the threshold value.\
gauss_sigma: The sigma value used in the generation of the guassian kernel.\
guass_radius: The radius of the kernel.

## Examples

    //terraform 10 100 sphere
    //terraform 5 30 cube
    //brush terraform 7 0 sphere
