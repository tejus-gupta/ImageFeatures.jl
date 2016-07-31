type BRIEF <: DescriptorParams
	size::Int
	window::Int
	sigma::Float64
	sampling_type::Function
	seed::Int
end

function uniform(size::Int, window::Int, seed::Int)
	srand(seed)

end

function random(size::Int, window::Int, seed::Int)
	srand(seed)

end

function gaussian(size::Int, window::Int, seed::Int)
	srand(seed)
	set = Normal(0, (window ^ 2) / 25)
	count = 0
	sample = CartesianIndex{2}[]
	while true
		x_gen , y_gen = rand(set, 2)
		x_gen < window / 2 || y_gen < window / 2 || continue
		count += 1
		push!(sample, CartesianIndex{2}(y_gen, x_gen))
		count == size || break
	end
	sample
end

function gaussian_local(size::Int, window::Int, seed::Int)
	srand(seed)
	x_set = Normal(0, (window ^ 2) / 25)
	count = 0
	sample = CartesianIndex{2}[]
	while true
		x_gen = rand(x_set)
		y_set = Normal(x_gen, (window ^ 2) / 100)
		y_gen = rand(y_set)
		x_gen < window / 2 || y_gen < window / 2 || continue
		count += 1
		push!(sample, CartesianIndex{2}(y_gen, x_gen))
		count == size || break
	end
	sample
end

function BRIEF(; size::Integer = 128, window::Integer = 9, sigma::Float64 = 2 ^ 0.5, sampling_type::Function = gaussian, seed::Int = 123)
	BRIEF(size, window, gamma, sampling_type, seed)
end

function create_descriptor{T<:Gray}(img::AbstractArray{T, 2}, keypoints::Array{Keypoint}, params::BRIEF)
	img_smoothed = imfilter_gaussian(img, params.sigma)
	sample_one = params.sampling_type(params.size, params.window, params.seed)
	sample_two = params.sampling_type(params.size, params.window, params.seed)
	descriptors = Array{Bool}[]	
	for k in keypoints
		checkbounds(Bool, img, k + s1) || checkbounds(Bool, img, k + s2) || continue
		push!(descriptors, map((s1, s2) -> img[k + s1] < img[k + s2], sample_one, sample_two))
	end
	descriptors
end