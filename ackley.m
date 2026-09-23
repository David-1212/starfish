% ackley.m
% CONFIGURACION DEL PROBLEMA + EJECUCION DEL SFOA
% ------------------------------------------------------------------
% Aqui se definen los valores de entrada que el SFOA necesita, se llama
% al algoritmo (SFOA.m) y se grafican los resultados.
%
% La funcion de Ackley esta definida MAS ABAJO como funcion local
% (codigo original de: https://www.sfu.ca/~ssurjano/Code/ackleym.html)

clear all; close all; clc

%% 1) VALORES DE ENTRADA (EDITABLES)
% Numero de individuos (estrellas de mar) de la poblacion
Npop = 50;

% Numero maximo de iteraciones del algoritmo
Max_it = 500;

% Limite inferior del dominio de busqueda
lb = -32.768;

% Limite superior del dominio de busqueda
ub = 32.768;

% Numero de dimensiones del problema
nD = 10;

% Handle a la funcion objetivo (la funcion de Ackley local de este archivo)
fobj = @ackleyfun;

%% 2) LLAMADA AL ALGORITMO SFOA
% SFOA devuelve 3 variables: mejor posicion, mejor fitness y curva de convergencia
[xpos, fval, Curve] = SFOA(Npop, Max_it, lb, ub, nD, fobj);

%% 3) RESULTADOS EN CONSOLA
% Se imprime la dimension configurada
fprintf('Dimension: %d\n', nD);

% Se imprime el mejor fitness encontrado
fprintf('Mejor fitness encontrado: %.6e\n', fval);

% Se imprime el valor de referencia del optimo global de Ackley
fprintf('Valor de referencia (optimo global): 0\n');

%% 4) GRAFICAS
% Grafica 1: convergencia del algoritmo
plotConvergence(Curve, Max_it);

% Grafica 2: superficie de la funcion de Ackley en 2D
plotAckleySurface(lb, ub);

%% ==================== FUNCIONES LOCALES ====================

% ------------------------------------------------------------------
% ackleyfun: la funcion objetivo de Ackley, tal cual el codigo de SFU.
% Solo cambia el nombre para que este archivo funcione como script.
% Entradas: xx = vector de coordenadas; a, b, c constantes con valor
% por defecto (20, 0.2, 2*pi).
% ------------------------------------------------------------------
function y = ackleyfun(xx, a, b, c)
% Numero de dimensiones del punto a evaluar
d = length(xx);

% Si no se paso c, se usa 2*pi (valor por defecto)
if (nargin < 4)
    c = 2*pi;
end

% Si no se paso b, se usa 0.2 (valor por defecto)
if (nargin < 3)
    b = 0.2;
end

% Si no se paso a, se usa 20 (valor por defecto)
if (nargin < 2)
    a = 20;
end

% Acumulador de la suma de cuadrados
sum1 = 0;

% Acumulador de la suma de cosenos
sum2 = 0;

% Bucle que recorre cada coordenada del vector xx
for ii = 1:d
    % Coordenada actual
    xi = xx(ii);
    % Se acumula xi^2 en sum1
    sum1 = sum1 + xi^2;
    % Se acumula cos(c*xi) en sum2
    sum2 = sum2 + cos(c*xi);
end

% Primer termino: exponencial que penaliza la magnitud de x
term1 = -a * exp(-b*sqrt(sum1/d));

% Segundo termino: exponencial de la suma de cosenos (ondulaciones)
term2 = -exp(sum2/d);

% Valor final de la funcion de Ackley
y = term1 + term2 + a + exp(1);
end

% ------------------------------------------------------------------
% plotConvergence: grafica la curva de convergencia en escala logaritmica.
% ------------------------------------------------------------------
function plotConvergence(Curve, Max_it)
% Crea una figura con fondo blanco
figure('Color', 'w');

% Traza el mejor fitness por iteracion con eje Y logaritmico
semilogy(1:Max_it, Curve, 'b-', 'LineWidth', 1.5);

% Activa la rejilla de la grafica
grid on;

% Etiqueta del eje X
xlabel('Iteracion');

% Etiqueta del eje Y
ylabel('Mejor fitness (log)');

% Titulo de la grafica
title('Convergencia de SFOA sobre la funcion de Ackley');

% Leyenda de la curva
legend('SFOA');

% Fuerza el renderizado inmediato de la figura
drawnow;
end

% ------------------------------------------------------------------
% plotAckleySurface: grafica la superficie 2D de la funcion de Ackley.
% ------------------------------------------------------------------
function plotAckleySurface(lb, ub)
% Numero de puntos por eje de la rejilla
n = 100;

% Vector de puntos equiespaciados en el eje X
x = linspace(lb, ub, n);

% Vector de puntos equiespaciados en el eje Y
y = linspace(lb, ub, n);

% Se crea la rejilla bidimensional (X y Y son matrices n x n)
[X, Y] = meshgrid(x, y);

% Matriz donde se guarda el valor de Ackley en cada punto
Z = zeros(n, n);

% Bucle por filas de la rejilla
for i = 1:n
    % Bucle por columnas de la rejilla
    for j = 1:n
        % Se evalua Ackley en el punto (X(i,j), Y(i,j))
        Z(i, j) = ackleyfun([X(i, j), Y(i, j)]);
    end
end

% Crea una figura con fondo blanco
figure('Color', 'w');

% Dibuja la superficie 3D sin lineas de malla
surf(X, Y, Z, 'EdgeColor', 'none');

% Define la paleta de colores
colormap(parula);

% Agrega la barra de valores
colorbar;

% Suaviza el relleno de colores
shading interp;

% Etiquetas de los ejes
xlabel('x_1'); ylabel('x_2'); zlabel('f(x_1, x_2)');

% Titulo de la grafica
title('Superficie de la funcion de Ackley');

% Angulo de vista de la camara en 3D
view(45, 30);

% Fuerza el renderizado inmediato de la figura
drawnow;
end