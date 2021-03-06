using ArgParse

function parse_commandline()
    cometin = ArgParseSettings()

    @add_arg_table cometin begin
        "--ising"
            help = "Interacción de Ising"
            arg_type = Float64
            default = .7
        "--bx"
            help = "Campo en x"
            arg_type = Float64
            default = .9
        "--by"
            help = "Campo en y"
            arg_type = Float64
            default = 0.
        "--bz"
            help = "Campo en z"
            arg_type = Float64
            default = .9
        "--qubits", "-q"
            help = "Número de qbits"
            arg_type = Int
            default = 12
            required = true
        "--subespacio", "-k"
            help = "Subespacio"
            arg_type = Int
            default = 8
            required = true
        "--archivo", "-f"
            help = "Archivo para leer ciclos"
            required = true
        "--salida", "-o"
            help = "Archivo de salida"
            required = true
    end

    return parse_args(cometin)
end
sigma_x=[0. 1.; 1. 0.]
sigma_y=[0. -im; im 0]
sigma_z=[1. 0.;0. -1.]
sigmas=Array[sigma_x, sigma_y, sigma_z]

getBytes(x::DataType) = sizeof(x);

function getBytes(x)
	total = 0;
	fieldNames = fieldnames(typeof(x));
	if fieldNames == []
		return sizeof(x);
	else
		for fieldName in fieldNames
			total += getBytes(getfield(x,fieldName));
		end
		return total;
	end
end

function apply_unitary!(psi, u, target_qubit)
    number_of_qubits = trailing_zeros(length(psi))
    end_outer_counter = 2^(number_of_qubits-target_qubit-1)-1
    for counter_left_bits = 0:end_outer_counter
        number_left=counter_left_bits<< (target_qubit+1)
        end_right_counter = number_left + (1<<target_qubit)-1
        for counter_right_bits = number_left:end_right_counter
            counter_right_bits_1 = counter_right_bits + (1<<target_qubit)
            psi[counter_right_bits+1], psi[counter_right_bits_1+1]=u*[psi[counter_right_bits+1], psi[counter_right_bits_1+1]]
        end
    end
end

function testbit(n, bit)
    ~(n&(1<<bit)==0)
end

function apply_ising!(psi, J, target_qubit_1, target_qubit_2)
    expJ=exp(-im*J)
    expJc=conj(expJ)
    for i = 0: length(psi)-1
        if testbit(i,target_qubit_1) $ testbit(i,target_qubit_2)
            psi[i+1]*=expJc
        else
            psi[i+1]*=expJ
        end
    end
end

function apply_kick!(psi, b, target_qubit)
    phi=norm(b)
    b_normalized=b/phi
    sigma_n=sigmas[1]*b_normalized[1]+sigmas[2]*b_normalized[2]+sigmas[3]*b_normalized[3]
    u=eye(2)*cos(phi)-im*sigma_n*sin(phi)
    apply_unitary!(psi, u, target_qubit)
end

function apply_magnetic_kick!(psi,b)
    qubits=trailing_zeros(length(psi))
    for i in 0:(qubits-1) 
        apply_kick!(psi,b,i)
    end
end

function apply_chain!(psi,J)
    qubits=trailing_zeros(length(psi))
    for i in 0:(qubits-2) 
        apply_ising!(psi,J,i,i+1)
    end
    apply_ising!(psi, J, qubits-1, 0)
end
function detraizmulti(k, l)
    for i in 1:l
        if mod(k*i, l) == 0
            return exp(2*pi*1im*k/l), i
        end
    end
end
function dearchivoaram(nombre, k, nqbits)
    puestos = Array{Int,1}[]
    raiz, multi = detraizmulti(k, nqbits)
	f = open(nombre)
	for ln in eachline(f)
	    coordenaday = vec(readdlm(IOBuffer(ln), ',', Int))
        if mod(length(coordenaday), multi) != 0
            continue
        end
        push!(puestos, coordenaday)
	end
	close(f)
    puestos
end
function loca(raiz, numero)
    lista = zeros(Complex{Float64}, numero)
    lista[1] = 1.+0im
    potencia = 1
    lista[end] = raiz^potencia
    potencia += 1
    for i in 1:numero - 2
        lista[ numero - i ] = raiz^potencia
        potencia += 1
    end
    lista
end
function generabase(k, numq, nombrearchivo)
    base = SparseVector{Complex{Float64},Int64}[]
    raiz, multiplicidad = detraizmulti(k, numq)
    listaderaices = loca(raiz, multiplicidad)
    listaimportante = dearchivoaram(nombrearchivo, k, numq)
    for vecA in listaimportante
        trebol = zeros(Complex{Float64}, vecA)
        mas = Int(length(trebol)/multiplicidad)
        grande = collect(1:length(trebol))
        beta = reshape(grande , (div(length(grande), mas), mas))
        for i in 1:mas
            trebol[ beta[ :,i ] ] = listaderaices
        end
        s = sparsevec(vecA, trebol, 2^numq)
        push!(base, s/norm(s))
    end
    base
end
function pruebasasesinas(nombrearchivo, k, numq)
    parsed_args = parse_commandline()
    bx = parsed_args["bx"]
    by = parsed_args["by"]
    bz = parsed_args["bz"]
    archivo = parsed_args["salida"]
    ising = parsed_args["ising"]
    base = generabase(k, numq, nombrearchivo)
    tamano = length(base)
    floquet = zeros(Complex{Float64}, tamano, tamano)
    j = 1
    cbase = deepcopy(base)
    while sizeof(base) > 0
    	@show getBytes(base)
    	@show getBytes(cbase)
        elementobaseA = full(shift!(base))
        apply_chain!(elementobaseA, ising)
        apply_magnetic_kick!(elementobaseA, [bx, by, bz])
        for elementobaseB in cbase
            floquet[j] = dot(elementobaseB, elementobaseA)
            j+=1
        end
    end
    gc()
    gg = eigfact(floquet)
    #archivofases = string(archivo, "_fases.dat")
    #archivoestados = string(archivo, "_estados.dat")
    #writedlm(archivofases, angle(gg[:values]), ", ")
    #writedlm(archivoestados,gg[:vectors], ", ")
    #putada
    ising = parsed_args["ising"]
    a = readstring(`./test_spins -q $(parsed_args["qubits"]) -k $(parsed_args["subespacio"]) -o david`)
    b = sort([eval(parse(replace(a[2:end-2], r" ", ",")))...])
    @show norm(b - sort(vec(angle(gg[:values]))))
    #putada
end
parsed_args = parse_commandline()
Nombre1 = parsed_args["archivo"]
Numq = parsed_args["qubits"]
k = parsed_args["subespacio"]
pruebasasesinas(Nombre1,k,Numq)
