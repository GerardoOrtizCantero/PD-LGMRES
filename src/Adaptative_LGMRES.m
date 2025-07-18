%modificado por jccf agosto 2024
%modificado Gerado Ortiz junio 2025

function [x,flag,relressvec,time,cycles, m_history] = ...
Adaptative_LGMRES(A, b, m, k, tol, maxit, xInitial)

% Adaptative LGMRES algorithm
    %
    %   LGMRES ("Loose GMRES") is a modified implementation of the restarted
    %   Generalized Minimal Residual Error or GMRES(m) [1], performed by
    %   appending 'k' error approximation vectors to the restarting Krylov
    %   subspace, as a way to preserve information from previous
    %   discarted search subspaces from previous iterations of the method.
    %
    %   Augments the standard GMRES approximation space with approximations
    %   to the error from previous restart cycles as in [1].
    %
    %   Signature:
    %   ----------
    %
    %   [x, flag, relresvec, time] = ...
    %       lgmres(A, b, m, k, tol, maxit, xInitial)
    %
    %
    %   Input Parameters:
    %   -----------------
    %
    %   A:          n-by-n matrix
    %               Left-hand side of the linear system Ax = b.
    %
    %   b:          n-by-1 vector
    %               Right-hand side of the linear system Ax = b.
    %
    %   m:          int
    %               Restart parameter (similar to 'restart' in MATLAB).
    %
    %   k:          int
    %               Number of error approximation vectors to be appended
    %               to the Krylov search subspace. Default is 3, but values
    %               between 1 and 5 are mostly used.
    %
    %   tol:        float, optional
    %               Tolerance error threshold for the relative residual norm.
    %               Default is 1e-6.
    %
    %   maxit:      int, optional
    %               Maximum number of outer iterations.
    %
    %   xInitial:   n-by-1 vector, optional
    %               Vector of initial guess. Default is zeros(n, 1).
    %
    %   Output parameters:
    %   ------------------
    %
    %   x:          n-by-1 vector
    %               Approximate solution to the linear system.
    %
    %   flag:       boolean
    %               1 if the algorithm has converged, 0 otherwise.
    %
    %   relressvec: (1 up to maxit)-by-1 vector
    %               Vector of relative residual norms of every outer iteration
    %               (cycles). The last relative residual norm is simply given
    %               by relresvec(end).
    %
    %   time:       scalar
    %               Computational time in seconds.
    %
    %   References:
    %   -----------
    %
    %   [1] Baker, A. H., Jessup, E. R., & Manteuffel, T. (2005). A technique
    %   for accelerating the convergence of restarted GMRES. SIAM Journal on
    %   Matrix Analysis and Applications, 26(4), 962-984.
    %
    %   Copyright:
    %   ----------
    %
    %   This file is part of the KrySBAS MATLAB Toolbox.
    %
    %   Copyright 2023 CC&MA - NIDTec - FP - UNA
    %
    %   KrySBAS is free software: you can redistribute it and/or modify it under
    %   the terms of the GNU General Public License as published by the Free
    %   Software Foundation, either version 3 of the License, or (at your
    %   option) any later version.
    %
    %   KrySBAS is distributed in the hope that it will be useful, but WITHOUT
    %   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    %   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
    %   for more details.
    %
    %   You should have received a copy of the GNU General Public License along
    %   with this file.  If not, see <http://www.gnu.org/licenses/>.
    %         
    
% ---------------------------
% ----> Sanity check on the number of input parameters
% ---------------------------
if nargin < 2
    error("Too few input parameters. Expected at least A and b.");
elseif nargin > 7
    error("Too many input parameters.");
end

% ---------------------------
% ----> Sanity checks on matrix A
% Check whether A is non-empty
% ---------------------------
if isempty(A)
    error("Matrix A cannot be empty.");
end

% ---------------------------
% Check whether A is square
% ---------------------------
[rowsA, colsA] = size(A);
if rowsA ~= colsA
    error("Matrix A must be square.");
end
n = rowsA;
clear rowsA colsA;

% ---------------------------
% ----> Sanity checks on vector b
% Check whether b is non-empty
% ---------------------------
if isempty(b)
    error("Vector b cannot be empty.");
end

% ---------------------------
% Check whether b is a column vector
% ---------------------------
[rowsb, colsb] = size(b);
if colsb ~= 1
    error("Vector b must be a column vector.");
end

% ---------------------------
% Check whether b has the same number of rows as b
% ---------------------------
if rowsb ~= n
    error("Dimension mismatch between matrix A and vector b.");
end
clear rowsb colsb;

% ---------------------------
% Special sanity checks for LGMRES here
% ---------------------------

% ---------------------------
% ----> Default value and sanityu checks for m
% ---------------------------
if (nargin < 3) || isempty(m)
    m = min(n, 10);
end

% ---------------------------
% ----> If m > n, error message is printed
% ---------------------------
if m > n
    error("m must satisfy: 1 <= m <= n.");
end

% ---------------------------
% ----> If m == n, built-in unrestarted gmres will be used
% ---------------------------
if m == n
    warning("Full GMRES will be used.");
    tic();
    [gmres_x, gmres_flag, ~, ~, resvec] = gmres(A, b);
    time = toc();
    x = gmres_x;
    if gmres_flag == 0
        flag = 1;
    else
        flag = 0;
    end
    relresvec = resvec ./ resvec(1, 1);
    return
end

% ---------------------------
% ----> If m < n AND k == 0, built-in gmres(m) will be used
% ---------------------------
if any(m < n) && any(k == 0)
    warning("GMRES(m) will be used.");
    tic();
    [gmres_x, gmres_flag, ~, ~, resvec] = gmres(A, b, m);
    time = toc();
    x = gmres_x;
    if gmres_flag == 0
        flag = 1;
    else
        flag = 0;
    end
    relresvec = resvec ./ resvec(1, 1);
    return
end

% ---------------------------
% ----> Default value and sanity checks for k
% ---------------------------
if (nargin < 4) || isempty(k)
    k = 3;
end

% ---------------------------
% Default value and sanity checks for tol
% ---------------------------
if (nargin < 5) || isempty(tol)
    tol = 1e-6;
end
if tol < eps
    warning("Tolerance is too small and it will be changed to eps.");
    tol = eps;
elseif tol >= 1
    warning("Tolerance is too large and it will be changed to 1-eps.");
    tol = 1 - eps;
end

% ---------------------------
% ----> Default value for maxit
% ---------------------------
if (nargin < 6) || isempty(maxit)
    maxit = min(n, 10);
end

% ---------------------------
% ----> Default value and sanity checks for initial guess xInitial
% ---------------------------
if (nargin < 7) || isempty(xInitial)
    xInitial = zeros(n, 1);
end

% ---------------------------
% Check whether xInitial is a column vector
% ---------------------------
[rowsxInitial, colsxInitial] = size(xInitial);
if colsxInitial ~= 1
    error("Initial guess xInitial is not a column vector.");
end

% ---------------------------
% Check whether x0 has the right dimension
% ---------------------------
if rowsxInitial ~= n
    msg = "Dimension mismatch between matrix A and initial guess xInitial.";
    error(msg);
end
clear rowsxInitial colsxInitial;

% ---------------------------
% ---------- CONFIGURACIÓN DEL ALGORITMO ----------
% ---------------------------
restart = 1;
r0 = b - A * xInitial;
res(1, :) = norm(r0);
relresvec(1, :) = (norm(r0) / res(1, 1));
iter(1, :) = restart;
d=k;
m_history = []; % Vector para almacenar los valores de m

% Matriz para almacenar los vectores de error de ciclos anteriores z_j = x_i - x_{i-1}
zMat = zeros(n, k);

% while number_of_cycles <=k, we run GMRES(m + k) only
tic(); % start measuring CPU time

% Ejecuta un GMRES(m + k) normal, como recomienda Baker libro (2005)
[x, gmres_flag, ~, ~, resvec] = ...
        gmres(A, b, m + k, tol, 1, [], [], xInitial);

% Update residual norm, iterations, and relative residual vector
res(restart + 1, :) = resvec(end);
iter(restart + 1, :) = restart + 1;
relresvec(size(relresvec, 1) + 1, :) = resvec(end) / res(1, 1);

% First approximation error vector
zMat(:, restart) = x - xInitial;

% gmres uses a flag system. We only care whether the solution has///////////
% converged or not
if gmres_flag ~= 0 % if gmres did not converge
    flag = 0;
    xInitial = x;
    restart = restart + 1;
else
    flag = 1;
    time = toc();
    return
end

% ---------------------------
% ---------- INICIALIZACIÓN PARA PRÓXIMOS CICLOS ----------
% ---------------------------
w=zeros(n,m+d); 
z=zeros(n,1);
ij=1; % Índice para controlar almacenamiento en matriz z
minitial=m;
logres(1,:)=(norm(r0)/res(1,1));
iter(1,:)=restart;
miteracion(1,1)=minitial;

% ---------------------------
% Configuración de límites y parámetros del controlador PD
% ---------------------------
mmin=1; % Valor mínimo permitido para m
mmax=n-1; % Valor máximo permitido (no se permite GMRES completo)
mstep=1; % Incremento si m cae fuera de rango permitido
alpha0=2; % Coeficiente proporcional del controlador PD
delta0=0; % Coeficiente derivativo del controlador PD

% ---------------------------
%iterative cycle starts
% ---------------------------
while flag==0
     % ACTUALIZACIÓN DEL PARÁMETRO m CON CONTROLADOR PD
     if iter(size(iter,1),:) ~=1
        % Calcula nuevo m adaptativo usando regla PD
        [miter]=pdrule(m,minitial,mmin,res,iter(size(iter,1),:),mstep, mmax,alpha0, delta0); 
        m=miter(1,1);
        minitial=miter(1,2);
        m_history = [m_history; m];  %Almacenar el valor de m
     else
        % En el primer ciclo, se mantiene el valor inicial
        m=minitial;
    end
    miteracion(iter(size(iter,1),:)+1,1)=m;

    % ---------------------------
    % INICIALIZACIÓN DE VARIABLES PARA ESTE CICLO
    % ---------------------------
    beta=norm(r0);
    v(:,1)=r0/beta;
    h=zeros(m+1,m);

    % ---------------------------
    % CASO: SOLO GMRES CLÁSICO (sin z_j aún)
    % ---------------------------
    if size(logres,1)==1
        % Proceso de Arnoldi con Gram-Schmidt modificado
        for j=1:m                       
            w(:,j)=A*v(:,j);
            for i=1:j
                h(i,j)=w(:,j)'*v(:,i);
                w(:,j)=w(:,j)-h(i,j)*v(:,i);
            end
            h(j+1,j)=norm(w(:,j));
            if h(j+1,j)==0
                m=j;
                h2=zeros(m+1,m);
                for k=1:m
                    h2(:,k)=h(:,k);
                end
                h=h2;
            else
                v(:,j+1)=w(:,j)/h(j+1,j);
            end
        end
        % Construcción del sistema proyectado g = [β; 0; ...]
        g=zeros(m+1,1);
        g(1,1)=beta;

        % Aplicación de rotaciones de planos (Givens) para triangular h
        for j=1:m                       
            P=eye(m+1);
            sin=h(j+1,j)/(sqrt(h(j+1,j)^2 + h(j,j)^2));
            cos=h(j,j)/(sqrt(h(j+1,j)^2 + h(j,j)^2));
            P(j,j)=cos;
            P(j+1,j+1)=cos;
            P(j,j+1)=sin;
            P(j+1,j)=-sin;
            h=P*h;
            g=P*g;
        end

        % Resolución del sistema triangular R y = g
        R=zeros(m,m);
        G=zeros(m,1);
        V=zeros(n,m);
        for k=1:m
            G(k)=g(k);
            V(:,k)=v(:,k);
            for i=1:m
                R(k,i)=h(k,i);
            end
        end
        minimizer=R\G;
        Z=V*minimizer;

        % Actualiza solución y residuo
        xm=xInitial + Z;
        r0=b-A*xm;

        % Guarda valores
        miteracion(size(miteracion,1)+1,1)=m;
        res(restart+1,:)=norm(r0);
        iter(restart+1,:)=restart+1;
        logres(size(logres,1)+1,:)=norm(r0)/res(1,1);

        % Criterio de convergencia
        if logres(size(logres,1)) <tol
            flag=1;
        else
            xInitial=xm; % Prepara siguiente ciclo
            restart=restart+1;
        end

        % Guarda vector de corrección z
        z(:,ij)= Z;

    % ---------------------------
    % CASO: HAY VECTORES z_j DISPONIBLES (LGMRES completo)
    % ---------------------------
    else
        if ij<=d
            d=ij;
            ij=ij+1;
        end
        s=m+d;
        % Proceso de Arnoldi modificado para espacio aumentado
        for j=1:s                       
                if j<=m
                    w(:,j)=A*v(:,j);
                else
                    w(:,j)=A*z(:,d-(j-m-1));
                end
            for i=1:j
                h(i,j)=w(:,j)'*v(:,i);
                w(:,j)=w(:,j)-h(i,j)*v(:,i);
            end
            h(j+1,j)=norm(w(:,j));
            if h(j+1,j)==0
                s=j;
                h2=zeros(s+1,s);
                for k=1:s
                    h2(:,k)=h(:,k);
                end
                h=h2;
            else
            v(:,j+1)=w(:,j)/h(j+1,j);
            end
        end

        % Construcción del sistema proyectado extendido
        g=zeros(s+1,1);
        g(1,1)=beta;

        % Aplicación de rotaciones de planos (Givens)
        for j=1:s                       
            P=eye(s+1);
            sin=h(j+1,j)/(sqrt(h(j+1,j)^2 + h(j,j)^2));
            cos=h(j,j)/(sqrt(h(j+1,j)^2 + h(j,j)^2));
            P(j,j)=cos;
            P(j+1,j+1)=cos;
            P(j,j+1)=sin;
            P(j+1,j)=-sin;
            h=P*h;
            g=P*g;
        end

        % Resolución del sistema proyectado
        R=zeros(s,s);
        G=zeros(s,1);
        V=zeros(n,s);
        for k=1:s
            G(k)=g(k);
            V(:,k)=v(:,k);
            for i=1:s
                R(k,i)=h(k,i);
            end
        end
        for k=m+1:s
            V(:,k)=z(:,d-(k-m-1));
        end
        minimizer=R\G;
        xm=xInitial+V*minimizer;

        % Actualiza solución, residuo y vectores de enriquecimiento
        iter(restart+1,:)=restart+1;
        r0=b-A*xm;
        miteracion(size(miteracion,1)+1,1)=m;
        res(restart+1,:)=norm(r0);
        iter(restart+1,:)=restart+1;
        logres(size(logres,1)+1,:)=norm(r0)/res(1,1);
        aux=V*minimizer;
        Z=z;
        if size(z,2)<d
            z(:,size(z,2)+1)=aux;
        else
            for j=2:d
                z(:,j-1)=Z(:,j);
            end
                z(:,d)=aux;
        end

         % Criterio de convergencia
         if logres(size(logres,1),1) <tol || size(logres,1)==maxit
            flag=1;
         else
            xInitial=xm;% Prepara siguiente ciclo
            restart=restart+1;
         end


    end % Fin del else 

end   % Fin del while

% ---------------------------
%retorno de variables
% ---------------------------
time=toc;     %Imprime tiempo de ejecucion
lastcycle=size(logres,1);
cycles= lastcycle;
relressvec=logres;


