function [xposbest, fvalbest, Curve] = SFOA(Npop, Max_it, lb, ub, nD, fobj)
% SFOA - Starfish Optimization Algorithm (algoritmo vanilla)
% Paper: C. Zhong, G. Li, Z. Meng, H. Li, A. R. Yildiz, S. Mirjalili.
% Neural Computing and Applications, 2025, 37: 3641-3683.
%
% ENTRADAS (las define y envia el archivo de la funcion, p. ej. ackley.m):
%   Npop   : numero de individuos de la poblacion (>= 5 por los "brazos")
%   Max_it : iteraciones maximas del bucle principal
%   lb     : limite inferior del dominio (escalar o vector 1 x nD)
%   ub     : limite superior del dominio (escalar o vector 1 x nD)
%   nD     : numero de dimensiones del problema
%   fobj   : handle de la funcion objetivo a minimizar
%
% SALIDAS (se regresan al archivo que llamo al SFOA):
%   xposbest : mejor posicion encontrada (1 x nD)
%   fvalbest : mejor valor de fitness encontrado (escalar)
%   Curve    : mejor fitness por iteracion (1 x Max_it)

%% Parametros del algoritmo
% GP = probabilidad de exploracion (el resto del tiempo explota)
GP = 0.5;

% Si los limites son escalares, se convierten en vectores de tamano nD
if size(ub, 2) == 1
    lb = lb * ones(1, nD);
    ub = ub * ones(1, nD);
end

%% Inicializacion
% fvalbest arranca en infinito para que cualquier fitness lo mejore
fvalbest = inf;

% Curve guarda el mejor fitness de cada iteracion (convergencia)
Curve = zeros(1, Max_it);

% Se crea la poblacion inicial aleatoria dentro de [lb, ub]
Xpos = initializePopulation(Npop, nD, lb, ub);

% Se evalua la funcion objetivo en toda la poblacion
Fitness = evaluateObjective(Xpos, fobj);

% Se busca el mejor fitness y el individuo que lo logro
[fvalbest, order] = min(Fitness);

% Se guarda la mejor posicion encontrada (el lider)
xposbest = Xpos(order, :);

%% Bucle principal de evolucion
% Contador de iteraciones
T = 1;

% Se repite hasta alcanzar el numero maximo de iteraciones
while T <= Max_it
    % Angulo de control: crece de 0 hacia pi/2 con las iteraciones
    theta = pi / 2 * T ./ Max_it;

    % Factor de equilibrio exploracion/explotacion (decae de 1 a 0)
    tEO = (Max_it - T) / Max_it * cos(theta);

    % Con probabilidad GP se explora, si no, se explota
    if rand < GP
        % Fase de exploracion: genera candidatos dispersos
        newX = explorationPhase(Npop, nD, lb, ub, Xpos, xposbest, GP, theta, tEO);
    else
        % Fase de explotacion: afina en torno al mejor global
        newX = exploitationPhase(Npop, nD, lb, ub, Xpos, xposbest, T, Max_it);
    end

    %% Actualizacion voraz (greedy)
    % Se recorre cada individuo para comparar su candidato con su posicion
    for i = 1:Npop
        % Se evalua el candidato con la funcion objetivo
        newFit = feval(fobj, newX(i, :));

        % Solo se acepta el cambio si el candidato es mejor
        if newFit < Fitness(i)
            Fitness(i) = newFit;      % se actualiza el fitness del individuo
            Xpos(i, :) = newX(i, :);  % se actualiza su posicion

            % Si ademas supera al mejor global, se actualiza el lider
            if newFit < fvalbest
                fvalbest = newFit;
                xposbest = Xpos(i, :);
            end
        end
    end

    % Se registra el mejor fitness de la iteracion T
    Curve(T) = fvalbest;

    % Se avanza a la siguiente iteracion
    T = T + 1;
end

end

%% ==================== FUNCIONES LOCALES ====================

% ------------------------------------------------------------------
% initializePopulation: crea la poblacion inicial aleatoria.
% devuelve una matriz Npop x nD con valores uniformes en [lb, ub].
% ------------------------------------------------------------------
function Xpos = initializePopulation(Npop, nD, lb, ub)
% rand(Npop,nD) genera valores en [0,1); .*(ub-lb) escala al rango y +lb
% desplaza al inicio del intervalo
Xpos = rand(Npop, nD) .* (ub - lb) + lb;
end

% ------------------------------------------------------------------
% evaluateObjective: evalua la funcion objetivo en toda la poblacion.
% devuelve un vector Fitness con la evaluacion de cada individuo.
% ------------------------------------------------------------------
function Fitness = evaluateObjective(Xpos, fobj)
% Se inicializa el vector de fitness
Fitness = zeros(1, size(Xpos, 1));

% Se recorre cada individuo de la poblacion
for i = 1:size(Xpos, 1)
    % feval llama a la funcion apuntada por el handle fobj
    Fitness(i) = feval(fobj, Xpos(i, :));
end
end

% ------------------------------------------------------------------
% explorationPhase: fase de exploracion de la estrella de mar.
% Usa el patron de 5 brazos (si nD > 5) o el patron uni-dimensional.
% devuelve newX con los candidatos generados.
% ------------------------------------------------------------------
function newX = explorationPhase(Npop, nD, lb, ub, Xpos, xposbest, GP, theta, tEO)
% Las dimensiones no seleccionadas conservan su valor original
newX = Xpos;

% Se genera un candidato para cada individuo
for i = 1:Npop

    % Si hay mas de 5 dimensiones se usa el patron de los 5 brazos
    if nD > 5
        % Se eligen 5 dimensiones distintas al azar (los brazos)
        jp1 = randperm(nD, 5);

        % Se recorre cada brazo (dimension) seleccionado
        for j = 1:5
            % Angulo aleatorio entre -pi y pi (da direccion y magnitud)
            pm = (2 * rand - 1) * pi;

            % Con probabilidad GP se usa coseno, si no, seno
            if rand < GP
                % Movimiento con coseno: paso grande hacia el mejor global
                newX(i, jp1(j)) = Xpos(i, jp1(j)) + pm * (xposbest(jp1(j)) - Xpos(i, jp1(j))) * cos(theta);
            else
                % Movimiento con seno: paso fino sobre el mismo vector
                newX(i, jp1(j)) = Xpos(i, jp1(j)) - pm * (xposbest(jp1(j)) - Xpos(i, jp1(j))) * sin(theta);
            end

            % Si el candidato se sale del rango, se conserva la posicion original
            if newX(i, jp1(j)) > ub(jp1(j)) || newX(i, jp1(j)) < lb(jp1(j))
                newX(i, jp1(j)) = Xpos(i, jp1(j));
            end
        end
    else
        % Si nD es pequeno se usa el patron uni-dimensional
        % Se elige una dimension aleatoria entre 1 y nD
        jp2 = ceil(nD * rand);

        % Permutacion de individuos para elegir 2 al azar
        im = randperm(Npop);

        % Coeficientes aleatorios en [-1, 1]
        rand1 = 2 * rand - 1;
        rand2 = 2 * rand - 1;

        % Combinacion de la posicion propia y de 2 individuos aleatorios
        newX(i, jp2) = tEO * Xpos(i, jp2) ...
            + rand1 * (Xpos(im(1), jp2) - Xpos(i, jp2)) ...
            + rand2 * (Xpos(im(2), jp2) - Xpos(i, jp2));

        % Si el candidato se sale del rango, se conserva la posicion original
        if newX(i, jp2) > ub(jp2) || newX(i, jp2) < lb(jp2)
            newX(i, jp2) = Xpos(i, jp2);
        end
    end

    % Recorte de limites: se fuerzan todas las coordenadas a [lb, ub]
    newX(i, :) = clipToBounds(newX(i, :), lb, ub);
end
end

% ------------------------------------------------------------------
% exploitationPhase: fase de explotacion (depredacion y regeneracion).
% Crea 5 vectores direccionales hacia el mejor global (los brazos) y
% desplaza a cada individuo con una combinacion de 2 de ellos.
% ------------------------------------------------------------------
function newX = exploitationPhase(Npop, nD, lb, ub, Xpos, xposbest, T, Max_it)
% Las posiciones actuales son el punto de partida
newX = Xpos;

% Se eligen 5 individuos aleatorios (los brazos)
df = randperm(Npop, 5);

% Se crean los vectores direccionales desde cada brazo hacia el mejor global
dm(1, :) = xposbest - Xpos(df(1), :);
dm(2, :) = xposbest - Xpos(df(2), :);
dm(3, :) = xposbest - Xpos(df(3), :);
dm(4, :) = xposbest - Xpos(df(4), :);
dm(5, :) = xposbest - Xpos(df(5), :);

% Se procesa a cada individuo
for i = 1:Npop
    % Pesos aleatorios en [0, 1]
    r1 = rand; r2 = rand;

    % Se eligen 2 de los 5 brazos al azar
    kp = randperm(length(df), 2);

    % Depredacion: se avanza hacia el mejor global combinando 2 brazos
    newX(i, :) = Xpos(i, :) + r1 * dm(kp(1), :) + r2 * dm(kp(2), :);

    % Regeneracion: el ultimo individuo encoje su posicion (factor exponencial)
    if i == Npop
        newX(i, :) = exp(-T * Npop / Max_it) .* Xpos(i, :);
    end

    % Recorte de limites: se fuerzan todas las coordenadas a [lb, ub]
    newX(i, :) = clipToBounds(newX(i, :), lb, ub);
end
end

% ------------------------------------------------------------------
% clipToBounds: recorta cada coordenada de X para que quede en [lb, ub].
% equivale a proyectar el punto hacia el dominio valido.
% ------------------------------------------------------------------
function X = clipToBounds(X, lb, ub)
% min(X,ub) limita por arriba; max(...,lb) limita por abajo
X = max(min(X, ub), lb);
end