%% benchmark_ackley.m
% Benchmark enfocado SOLO en la funcion de Ackley (SFU).
% Genera UN solo Excel con:
%   - 1000 filas: cada iteracion del SFOA
%   - N columnas: cada experimento (corrida independiente)
%   - Cada celda = mejor fitness encontrado hasta esa iteracion
%   - Resalta (verde) el mejor fitness de cada COLUMNA (experimento)
%     y (amarillo) el mejor fitness de cada FILA (iteracion),
%     ambos como el valor mas cercano al objetivo de la pagina (0).

%% Configuracion
Npop   = 20;          % individuos (SFOA requiere >= 5)
Max_it = 1000;        % iteraciones (= filas del Excel)
nExp   = 30;          % experimentos (= columnas del Excel)
lb     = -32.768;
ub     = 32.768;
nD     = 10;          % dimensiones
target = 0;           % optimo global de Ackley segun la pagina de SFU
fobj   = @ackleyfun;

tol = 1e-2;           % tolerancia auxiliar (no se usa para el resaltado)

%% Corridas
fprintf('Config: Npop=%d, Max_it=%d, Experimentos=%d\n', Npop, Max_it, nExp);

% M(i, e) = mejor fitness de la iteracion i en el experimento e
M = nan(Max_it, nExp);
for e = 1:nExp
    [~, ~, Curve] = SFOA(Npop, Max_it, lb, ub, nD, fobj);
    M(:, e) = Curve(:);
    fprintf('Experimento %02d/%d listo\n', e, nExp);
end

% Distance la objetivo: lo "cercano" se mide con |fitness - target|
dist = abs(M - target);

% Mejor de cada columna (experimento): iteracion mas cercana al objetivo
[~, bestRowCol] = min(dist, [], 1);   % 1 x nExp  (indice de fila)
% Mejor de cada fila (iteracion): experimento mas cercano al objetivo
[~, bestColRow] = min(dist, [], 2);   % Max_it x 1 (indice de columna)

%% Excel (un solo archivo)
outDir   = fullfile(pwd, 'experimentos_ackley');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
archivo  = fullfile(outDir, 'resultados_ackley.xlsx');
archivo  = char(java.io.File(archivo).getCanonicalPath());

% Hoja 'Datos': matriz Max_it x nExp con fila/columna de iteracion/experimento,
% la fila "Minimos" con el mejor fitness (minimo) de cada columna y debajo
% las estadisticas (Media, Desviacion estandar, Peor) de esos minimos
bestCols = min(M, [], 1);       % mejor fitness de cada experimento (ultima fila)
media    = mean(bestCols);      % media de los mejores fitness
desv     = std(bestCols);       % desviacion estandar de los mejores fitness
peor     = max(bestCols);       % peor (mayor) mejor fitness entre todos

% Etiquetas de las filas: iteraciones + filas de resumen
labels = [num2cell((1:Max_it)'); {'Minimos'; 'Media'; 'Desviacion estandar'; 'Peor'}];

% Matriz de datos mas filas de resumen (solo la columna "Mejor" se llena en esas filas)
matDatos = [M; bestCols; nan(3, nExp)];
colMejor = [nan(Max_it, 1); min(M, [], 'all'); media; desv; peor];

Tabla = [table(labels, 'VariableNames', {'Iteracion'}), array2table(matDatos), table(colMejor, 'VariableNames', {'Mejor'})];
Tabla.Properties.VariableNames = [{'Iteracion'}, arrayfun(@(k) sprintf('Exp%02d', k), 1:nExp, 'UniformOutput', false), {'Mejor'}];

% Archivo limpio: se elimina el previo para no conservar celdas viejas
if exist(archivo, 'file')
    delete(archivo);
end
writetable(Tabla, archivo, 'Sheet', 'Datos');

% Hoja 'Resumen': parametros y objetivo tomado de la pagina de SFU
resumen = table({'Funcion'; 'Dimension'; 'Dominio'; 'Objetivo (pagina)'; 'Npop'; 'Max_it'; 'nExp'}, ...
    {'Ackley (SFU)'; nD; sprintf('[%.3f, %.3f]', lb, ub); target; Npop; Max_it; nExp}, ...
    'VariableNames', {'Parametro', 'Valor'});
writetable(resumen, archivo, 'Sheet', 'Resumen', 'Range', 'A1');

%% Resaltado con Excel (COM)
VERDE   = 43520;      % RGB(0,170,0)  -> mejor de columna (experimento)
AMARILLO = 65535;     % RGB(255,255,0)-> mejor de fila (iteracion)

Excel = actxserver('Excel.Application');
try
    Excel.Visible = 0;
    wb  = Excel.Workbooks.Open(archivo);
    sh  = wb.Sheets.Item('Datos');
    % Nombres de columna de hoja (Iteracion=A, Exp01=B, ..., Mejor)
    ultimaCol = nExp + 2;
    ultimaFila = size(Tabla, 1) + 1;
    colLetras = celdaLetras(ultimaCol);

    % Formato cientifico para todos los valores
    sh.Range(sprintf('B2:%s%d', colLetras{ultimaCol}, ultimaFila)).NumberFormat = '0.000E+00';

    pintado = false(Max_it, nExp);   % evita repintar celdas

    % Verde: mejor de cada columna (experimento)
    for c = 1:nExp
        r = bestRowCol(c);
        sh.Range(sprintf('%s%d', colLetras{c + 1}, r + 1)).Interior.Color = VERDE;
        pintado(r, c) = true;
    end

    % Amarillo: mejor de cada fila (iteracion)
    for r = 1:Max_it
        c = bestColRow(r);
        if ~pintado(r, c)
            sh.Range(sprintf('%s%d', colLetras{c + 1}, r + 1)).Interior.Color = AMARILLO;
        end
    end

    wb.Save();
    wb.Close(false);
catch ME
    fprintf('Error coloreando %s:\n%s\n', archivo, getReport(ME));
end
Excel.Quit();
delete(Excel);

fprintf('\nTerminado. Excel creado: %s\n', archivo);

%% ==================== FUNCION LOCAL ====================
% Ackley (domino [-32.768, 32.768], minimo global f(0,...,0) = 0)
% tomada de la pagina de SFU: https://www.sfu.ca/~ssurjano/ackley.html
function y = ackleyfun(x)
n = numel(x);
sumsq = sum(x.^2);
sumcos = sum(cos(2 * pi * x));
y = -20 * exp(-0.2 * sqrt(sumsq / n)) - exp(sumcos / n) + 20 + exp(1);
end

% ------------------------------------------------------------------
% celdaLetras: devuelve nombres de columna de hoja de calculo
% (A, B, ..., Z, AA, AB, ...) para indices 1..n.
% ------------------------------------------------------------------
function letras = celdaLetras(n)
letras = {};
for k = 1:n
    kk = k;
    s = '';
    while kk > 0
        rem_ = mod(kk - 1, 26);
        s = [char('A' + rem_), s];
        kk = floor((kk - 1) / 26);
    end
    letras{end + 1} = s;
end
end



david vargas