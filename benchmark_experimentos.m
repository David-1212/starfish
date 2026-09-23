% benchmark_experimentos.m
% COMPARA EL SFOA SOBRE LAS 10 PRIMERAS FUNCIONES DE SFU
% https://www.sfu.ca/~ssurjano/optimization.html
% Cada experimento ejecuta SFOA en las 10 funciones y genera un Excel
% con su mejor fitness. Se colorea (verde) la celda que alcanzo el optimo
% global segun la pagina y (amarillo) la celda del que se acerco MAS sin
% alcanzarlo.
%
% CONFIG: Npop individuos, Max_it iteraciones, nExp experimentos.

clear all; close all; clc

%% ==================== CONFIGURACION (EDITABLE) ====================
% Individuos, iteraciones y experimentos
Npop   = 20;
Max_it = 1000;
nExp   = 50;

% Tolerancia para considerar que se ALCANZO el optimo global
% (diferencia relativa: |mejor - optimo| <= tol * max(1, |optimo|))
tol = 1e-2;

% Carpeta donde se guardan los Excels por experimento
outDir = 'experimentos';

%% ==================== CATALOGO DE FUNCIONES ====================
% Columnas: Nombre | handle local | d | lb | ub | Optimo global (pagina)
% Nota: se usa @x_bf porque ackley.m ya es el script de configuracion;
% las funciones objetivo van como funciones locales al final de este archivo.
funciones = {
    'Ackley',               @ackley_bf,    10, -32.768,  32.768,  0
    'Bukin N.6',            @bukin6_bf,    2,  [-15 -3], [-5  3],  0
    'Cross-in-Tray',        @crossit_bf,   2,  -10,      10,      -2.06261
    'Drop-Wave',            @drop_bf,      2,  -5.12,    5.12,    -1
    'Eggholder',            @egg_bf,       2,  -512,     512,     -959.6407
    'Gramacy & Lee (2012)', @grlee12_bf,   1,  0.5,      2.5,     nan
    'Griewank',             @griewank_bf,  10, -600,     600,     0
    'Holder Table',         @holder_bf,    2,  -10,      10,      -19.2085
    'Langermann',           @langer_bf,    2,  0,        10,      -5.1621
    'Levy',                 @levy_bf,      10, -10,      10,      0
};

% Se calcula el optimo global de Gramacy & Lee numericamente
% (su pagina no lo reporta; es 1D multimodal en [0.5, 2.5])
xg = linspace(0.5, 2.5, 20001);
yg = arrayfun(@grlee12_bf, xg);
[ym, im] = min(yg);
opts = optimset('TolX', 1e-12);
[xgl, fgl] = fminbnd(@grlee12_bf, xg(max(im-1,1)), xg(min(im+1,numel(xg))), opts);
if fgl > ym
    fgl = ym;
end
funciones{6, 6} = fgl;

nf = size(funciones, 1);

% Se crea la carpeta de resultados si no existe
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ==================== BUCLE DE EXPERIMENTOS ====================
fprintf('Config: Npop=%d, Max_it=%d, Experimentos=%d\n\n', Npop, Max_it, nExp);

for e = 1:nExp
    % Vectores de resultados de este experimento
    bests  = zeros(nf, 1);
    opts_  = zeros(nf, 1);

    % Se ejecuta SFOA en cada funcion
    for k = 1:nf
        fh   = funciones{k, 2};
        nD   = funciones{k, 3};
        lb   = funciones{k, 4};
        ub   = funciones{k, 5};

        [~, fval, ~] = SFOA(Npop, Max_it, lb, ub, nD, fh);
        bests(k)  = fval;
        opts_(k)  = funciones{k, 6};
    end

    % Diferencia absoluta contra el optimo global
    difs = abs(bests - opts_);

    % Filas que ALCANZARON el optimo (dentro de tolerancia)
    verde = find(difs <= tol .* max(1, abs(opts_)));

    % Entre las que NO alcanzaron, la MAS CERCANA al optimo
    fallidas = find(difs > tol .* max(1, abs(opts_)));
    amarillo = NaN;
    if ~isempty(fallidas)
        [~, imn] = min(difs(fallidas));
        amarillo = fallidas(imn);
    end

    % Descripcion del dominio
    dominio = cell(nf, 1);
    for k = 1:nf
        lb = funciones{k, 4};
        ub = funciones{k, 5};
        if numel(lb) == 1 && numel(ub) == 1
            dominio{k} = sprintf('[%.1f, %.1f]', lb, ub);
        else
            dominio{k} = sprintf('[%.1f...%.1f] x [%.1f...%.1f]', lb(1), lb(end), ub(1), ub(end));
        end
    end

    % Estado por fila
    estado = repmat({'NO ALCANZO'}, nf, 1);
    for k = 1:nf
        if ismember(k, verde)
            estado{k} = 'ALCANZO';
        end
    end
    if ~isnan(amarillo)
        estado{amarillo} = 'MAS CERCANO';
    end

    % Nombre del archivo
    archivo = fullfile(outDir, sprintf('resultado_experimento_%02d.xlsx', e));

    % Ruta absoluta (Excel no resuelve rutas relativas via COM)
    archivoAbs = char(java.io.File(archivo).getCanonicalPath());

    % Tabla con los resultados del experimento
    nombre = cell(nf, 1);
    for k = 1:nf
        nombre{k} = funciones{k, 1};
    end
    nDim = zeros(nf, 1);
    for k = 1:nf
        nDim(k) = funciones{k, 3};
    end

    Tabla = table(nombre, nDim, dominio, opts_, bests, difs, estado, ...
        'VariableNames', {'Funcion','Dimension','Dominio','Optimo_global','Mejor_fitness','Diferencia','Estado'});
    writetable(Tabla, archivo, 'Sheet', 'Resultados');

    % Se colorea la columna de Mejor_fitness (column C, filas 2..nf+1)
    colorExcel(archivoAbs, nf, verde, amarillo);

    fprintf('Experimento %02d/%d listo -> %s  (alcanzaron: %d/%d)\n', ...
        e, nExp, archivo, numel(verde), nf);
end

fprintf('\nTerminado. %d Excels creados en la carpeta "%s".\n', nExp, outDir);

%% ==================== FUNCIONES LOCALES ====================

% ------------------------------------------------------------------
% colorExcel: abre el .xlsx con Excel, pinta la celda de "Mejor fitness"
% (columna C) en verde para las filas que alcanzaron el optimo y en
% amarillo para la mas cercana, y guarda.
% ------------------------------------------------------------------
function colorExcel(archivo, nf, verde, amarillo)
% Inicia la aplicacion de Excel
Excel = actxserver('Excel.Application');
try
    Excel.Visible = 0;
    wb = Excel.Workbooks.Open(archivo);
    sh = wb.Sheets.Item('Resultados');

    % Verde (RGB 0,170,0) para las filas que alcanzaron el optimo
    for r = verde(:)'
        sh.Range(sprintf('C%d', r + 1)).Interior.Color = 43520;
    end

    % Amarillo (RGB 255,255,0) para la mas cercana sin alcanzarlo
    if ~isnan(amarillo)
        sh.Range(sprintf('C%d', amarillo + 1)).Interior.Color = 65535;
    end

    wb.Save();
    wb.Close(false);
catch ME
    fprintf('Error coloreando %s: %s\n', archivo, ME.message);
end
Excel.Quit();
delete(Excel);
end

% ------------------------------------------------------------------
% ackley_bf: funcion de Ackley (codigo original de SFU).
% ------------------------------------------------------------------
function y = ackley_bf(xx, a, b, c)
d = length(xx);
if (nargin < 4)
    c = 2*pi;
end
if (nargin < 3)
    b = 0.2;
end
if (nargin < 2)
    a = 20;
end
sum1 = 0;
sum2 = 0;
for ii = 1:d
	xi = xx(ii);
	sum1 = sum1 + xi^2;
	sum2 = sum2 + cos(c*xi);
end
term1 = -a * exp(-b*sqrt(sum1/d));
term2 = -exp(sum2/d);
y = term1 + term2 + a + exp(1);
end

% ------------------------------------------------------------------
% bukin6_bf: Bukin Function N. 6 (SFU).
% ------------------------------------------------------------------
function y = bukin6_bf(xx)
x1 = xx(1);
x2 = xx(2);
term1 = 100 * sqrt(abs(x2 - 0.01*x1^2));
term2 = 0.01 * abs(x1+10);
y = term1 + term2;
end

% ------------------------------------------------------------------
% crossit_bf: Cross-in-Tray Function (SFU).
% ------------------------------------------------------------------
function y = crossit_bf(xx)
x1 = xx(1);
x2 = xx(2);
fact1 = sin(x1)*sin(x2);
fact2 = exp(abs(100 - sqrt(x1^2+x2^2)/pi));
y = -0.0001 * (abs(fact1*fact2)+1)^0.1;
end

% ------------------------------------------------------------------
% drop_bf: Drop-Wave Function (SFU).
% ------------------------------------------------------------------
function y = drop_bf(xx)
x1 = xx(1);
x2 = xx(2);
frac1 = 1 + cos(12*sqrt(x1^2+x2^2));
frac2 = 0.5*(x1^2+x2^2) + 2;
y = -frac1/frac2;
end

% ------------------------------------------------------------------
% egg_bf: Eggholder Function (SFU).
% ------------------------------------------------------------------
function y = egg_bf(xx)
x1 = xx(1);
x2 = xx(2);
term1 = -(x2+47) * sin(sqrt(abs(x2+x1/2+47)));
term2 = -x1 * sin(sqrt(abs(x1-(x2+47))));
y = term1 + term2;
end

% ------------------------------------------------------------------
% grlee12_bf: Gramacy & Lee (2012) Function (SFU).
% ------------------------------------------------------------------
function y = grlee12_bf(x)
term1 = sin(10*pi*x) / (2*x);
term2 = (x-1)^4;
y = term1 + term2;
end

% ------------------------------------------------------------------
% griewank_bf: Griewank Function (SFU).
% ------------------------------------------------------------------
function y = griewank_bf(xx)
d = length(xx);
sum = 0;
prod = 1;
for ii = 1:d
	xi = xx(ii);
	sum = sum + xi^2/4000;
	prod = prod * cos(xi/sqrt(ii));
end
y = sum - prod + 1;
end

% ------------------------------------------------------------------
% holder_bf: Holder Table Function (SFU).
% ------------------------------------------------------------------
function y = holder_bf(xx)
x1 = xx(1);
x2 = xx(2);
fact1 = sin(x1)*cos(x2);
fact2 = exp(abs(1 - sqrt(x1^2+x2^2)/pi));
y = -abs(fact1*fact2);
end

% ------------------------------------------------------------------
% langer_bf: Langermann Function (SFU), d=2 con parametros por defecto.
% ------------------------------------------------------------------
function y = langer_bf(xx)
m = 5;
c = [1, 2, 5, 2, 3];
A = [3, 5; 5, 2; 2, 1; 1, 4; 7, 9];
d = length(xx);
outer = 0;
for ii = 1:m
    inner = 0;
    for jj = 1:d
        xj = xx(jj);
        Aij = A(ii,jj);
        inner = inner + (xj-Aij)^2;
    end
    new = c(ii) * exp(-inner/pi) * cos(pi*inner);
    outer = outer + new;
end
y = outer;
end

% ------------------------------------------------------------------
% levy_bf: Levy Function (SFU).
% ------------------------------------------------------------------
function y = levy_bf(xx)
d = length(xx);
for ii = 1:d
	w(ii) = 1 + (xx(ii) - 1)/4;
end
term1 = (sin(pi*w(1)))^2;
term3 = (w(d)-1)^2 * (1+(sin(2*pi*w(d)))^2);
sum = 0;
for ii = 1:(d-1)
	wi = w(ii);
    new = (wi-1)^2 * (1+10*(sin(pi*wi+1))^2);
	sum = sum + new;
end
y = term1 + sum + term3;
end