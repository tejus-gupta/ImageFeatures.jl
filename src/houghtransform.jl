
"""
```
lines = hough_transform_standard(image, ρ, θ, threshold, linesMax)
```

Returns an vector of tuples corresponding to the tuples of (r,t) where r and t are parameters for normal form of line:
    x*cos(t) + y*sin(t) = r

r = length of perpendicular from (1,1) to the line
t = angle between perpendicular from (1,1) to the line and x-axis

The lines are generated by applying hough transform on the image.

Parameters:
    image       = Image to be transformed (eltype should be `Bool`)
    ρ           = Discrete step size for perpendicular length of line
    θ           = List of angles for which the transform is computed
    threshold   = No of points to pass through line for considering it valid
    linesMax    = Maximum no of lines to return

"""

function hough_transform_standard{T<:Union{Bool,Gray{Bool}}}(
            img::AbstractArray{T,2},
            ρ::Number, θ::Range,
            threshold::Integer, linesMax::Integer)


    #function to compute local maximum lines with values > threshold and return a vector containing them
    function findlocalmaxima(accumulator_matrix::Array{Integer,2},threshold::Integer)
        validLines = Vector{CartesianIndex}(0)
        for val in CartesianRange(size(accumulator_matrix))
            if  accumulator_matrix[val] > threshold &&
                accumulator_matrix[val] > accumulator_matrix[val[1],val[2] - 1] &&
                accumulator_matrix[val] >= accumulator_matrix[val[1],val[2] + 1] &&
                accumulator_matrix[val] > accumulator_matrix[val[1] - 1,val[2]] &&
                accumulator_matrix[val] >= accumulator_matrix[val[1] + 1,val[2]]
                push!(validLines,val)
            end
        end
        validLines
    end

    ρ > 0 || error("Discrete step size must be positive")

    height, width = size(img)
    ρinv = 1 / ρ
    numangle = length(θ)
    numrho = round(Integer,(2(width + height) + 1)*ρinv)

    accumulator_matrix = zeros(Integer, numangle + 2, numrho + 2)

    #Pre-Computed sines and cosines in tables
    sinθ, cosθ = sin.(θ).*ρinv, cos.(θ).*ρinv

    #Hough Transform implementation
    constadd = round(Integer,(numrho -1)/2)
    for pix in CartesianRange(size(img))
        if img[pix]
            for i in 1:numangle
                dist = round(Integer, pix[1] * sinθ[i] + pix[2] * cosθ[i])
                dist += constadd
                accumulator_matrix[i + 1, dist + 1] += 1
            end
        end
    end

    #Finding local maximum lines
    validLines = findlocalmaxima(accumulator_matrix, threshold)

    #Sorting by value in accumulator_matrix
    sort!(validLines, by = (x)->accumulator_matrix[x], rev = true)

    linesMax = min(linesMax, length(validLines))

    lines = Vector{Tuple{Number,Number}}(0)

    #Getting lines with Maximum value in accumulator_matrix && size(lines) < linesMax
    for l in 1:linesMax
        lrho = ((validLines[l][2]-1) - (numrho - 1)*0.5)*ρ
        langle = θ[validLines[l][1]-1]
        push!(lines,(lrho,langle))
    end

    lines

end

"""
```
circle_centers, circle_radius = hough_circle_gradient(img, scale, min_dist, canny_thres, vote_thres, min_radius, max_radius)
```
Returns two vectors, corresponding to circle centers and radius.

The circles are generated using a hough transform variant in which a non-zero point only votes for circle
centers perpendicular to the local gradient.

Parameters:
    img          = image to detect circles in
    scale        = relative accumulator resolution factor
    min_dist     = minimum distance between detected circle centers
    canny_thres  = upper threshold for canny, lower threshold=upper threshold/4
    vote_thres   = accumulator threshold for circle detection
    min_radius   = minimum circle radius
    max_radius   = maximum circle radius
"""

function hough_circle_gradient{T<:Integer}(
        img::AbstractArray{T,2},
        scale::Number, min_dist::Number,
        canny_thres::Number, vote_thres::Number,
        min_radius::Integer, max_radius::Integer)

    rows,cols=size(img)

    img_edges = canny(img, 1, canny_thres, canny_thres/4, percentile=false)
    dx, dy=imgradients(img, KernelFactors.ando3)
    _, img_phase = magnitude_phase(dx, dy)

    non_zeros=CartesianIndex{2}[]
    centers=CartesianIndex{2}[]
    circle_centers=CartesianIndex{2}[]
    circle_radius=Integer[]
    votes=zeros(Integer, Int(floor(rows/scale))+1, Int(floor(cols/scale))+1)

    f = CartesianIndex(map(r->first(r), indices(votes)))
    l = CartesianIndex(map(r->last(r), indices(votes)))

    for i in indices(img, 1)
        for j in indices(img, 2)
            if img_edges[i,j]!=0
                sin_theta = -cos(img_phase[i,j]);
                cos_theta = sin(img_phase[i,j]);

                for r in min_radius:max_radius
                    x=Int(floor((i+r*sin_theta)/scale))+1
                    y=Int(floor((j+r*cos_theta)/scale))+1
                    p=CartesianIndex(x,y)

                    if min(f,p)==f && max(l,p)==l
                        votes[p]+=1
                    end

                    x=Int(floor((i-r*sin_theta)/scale))+1
                    y=Int(floor((j-r*cos_theta)/scale))+1
                    p=CartesianIndex(x,y)

                    if min(f,p)==f && max(l,p)==l
                        votes[p]+=1
                    end
                end
                push!(non_zeros, CartesianIndex{2}(i,j));
            end
        end
    end

    for i in findlocalmaxima(votes)
        if votes[i]>vote_thres
            push!(centers, i);
        end
    end

    sort!(centers, lt=(a, b) -> votes[a]>votes[b])

    dist(a, b) = sqrt(sum(abs2, (a-b).I))
    votes=Array(Integer, Int(floor(dist(f,l))+1))

    for center in centers
        center=(center-1)*scale
        fill!(votes, 0)

        too_close=false
        for circle_center in circle_centers
            if dist(center, circle_center)< min_dist
                too_close=true
                break
            end
        end
        if too_close==true
            break
        end

        for point in non_zeros
            votes[Int(floor(dist(center, point)/scale))+1]+=1
        end

        voters, radius = findmax(votes)
        radius-=1

        if voters>vote_thres
            push!(circle_centers, center)
            push!(circle_radius, radius)
        end
    end
    return circle_centers, circle_radius
end
