SELECT *
FROM CovidAnalysis..CovidDeaths
ORDER BY 'location','date';

SELECT *
FROM CovidAnalysis..CovidVaccinations
ORDER BY 'location','date';


--Select data to be used
SELECT
    location
    , date
    , total_cases
    , new_cases
    , total_deaths
    , population
FROM CovidAnalysis..CovidDeaths
ORDER BY 1, 2

--Looking at percentage deaths out of cases in the United Kingdom
SELECT 
    location
    , date
    , total_cases
    , total_deaths
    , ROUND((total_deaths/total_cases)*100, 2) AS [Death Percentage]
FROM CovidAnalysis..CovidDeaths
WHERE location LIKE '%kingdom%'
ORDER BY 1, 2

--Looking at the total cases vs population
SELECT 
    location
    , date
    , total_cases
    , population
    , Round((total_cases/population)*100,7) AS [Case Percentage]
FROM CovidAnalysis..CovidDeaths
WHERE location LIKE '%kingdom%'
ORDER BY 1, 2

--Looking at maximum infected population percentage
SELECT
    location
    , population
    , MAX(total_cases) AS [Maximum Total Cases]
    , MAX((total_cases/population))*100 AS [Max Percent Infected]
FROM CovidAnalysis..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY [Max Percent Infected] DESC

--Looking at maximum infection rate
SELECT
    location
    , population
    , MAX(new_cases) AS [Maximum New Cases]
    , MAX(new_cases/population)*100 AS [Percent Infection Rate]
FROM CovidAnalysis..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY [Percent Infection Rate] DESC


--Daily infection rate for the U.K.
SELECT 
    location
    , date
    , new_cases
    , (new_cases/population)*100 AS [Percent Infection Rate]
FROM CovidAnalysis..CovidDeaths
WHERE location LIKE '%kingdom%'
ORDER BY 2

--Looking at highest death count population by country
SELECT 
    continent
	, location
    , MAX(total_deaths) AS [Maximum Death Count]
FROM CovidAnalysis..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent, location
ORDER BY [Maximum Death Count] DESC
--break down by continent instead
SELECT 
    location
    , MAX(total_deaths) AS [Maximum Death Count]
FROM CovidAnalysis..CovidDeaths
WHERE (continent IS NULL--entires with null continent have the continent in the location as combined value for that continent
    AND location NOT LIKE '%union%'--removing europian union values
    AND location NOT LIKE '%world%' )--removing values for the whole world
GROUP BY location
ORDER BY [Maximum Death Count] DESC


-- Global numbers
SELECT 
    date
    , SUM(new_cases) AS [Total New Cases]
    , SUM(total_cases) AS [Total Cases]
    , (SUM(new_cases)/SUM(total_cases))*100 AS [Percentage New Cases]
    , SUM(new_deaths) AS [Total Deaths]
    , SUM(total_deaths) AS [Total Deaths]
    , (SUM(new_deaths)/SUM(total_deaths))*100 AS [Percentage New Deaths]
FROM CovidAnalysis..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1,3


--Joining the two tables
SELECT *
FROM CovidAnalysis..CovidDeaths CD
JOIN CovidAnalysis..CovidVaccinations CV
    ON CD.location = CV.location
        AND CD.date = CV.date

--Looking at total population vs vaccinations
SELECT
    CD.continent
    , CD.location
    , CD.date
    , CV.new_vaccinations
    , SUM(CV.new_vaccinations) OVER (PARTITION BY CD.location ORDER BY CD.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Rolling Vaccionations]
FROM CovidAnalysis..CovidDeaths CD
JOIN CovidAnalysis..CovidVaccinations CV
    ON CD.location = CV.location
        AND CD.date = CV.date
WHERE CD.continent IS NOT NULL
ORDER BY 2, 3

--Use CTE to have "rolling vaccination" used in a calculation
WITH PopsVac (Continent, Location, Date, Population, NewVaccinations, RollingVaccination)
AS 
(
SELECT
    CD.continent
    , CD.location
    , CD.date
    , CD.population
    , CV.new_vaccinations
    , SUM(CV.new_vaccinations) OVER (PARTITION BY CD.location ORDER BY CD.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Rolling Vaccionations]
FROM CovidAnalysis..CovidDeaths CD
JOIN CovidAnalysis..CovidVaccinations CV
    ON CD.location = CV.location
        AND CD.date = CV.date
WHERE CD.continent IS NOT NULL
)
SELECT *
    , (RollingVaccination/Population)*100 AS [Percent Population Vaccinated]
FROM PopsVac

--use Temp table to have "rolling vaccination" used in a calculation
DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated (
    Continent nvarchar(255),
    Location nvarchar(255),
    Date datetime,
    Population numeric,
    New_vaccinations numeric,
    RollingPopleVaccinated numeric
)
INSERT INTO #PercentPopulationVaccinated
SELECT
    CD.continent
    , CD.location
    , CD.date
	, CD.population
    , CV.new_vaccinations
    , SUM(CV.new_vaccinations) OVER (PARTITION BY CD.location ORDER BY CD.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Rolling Vaccionations]
FROM CovidAnalysis..CovidDeaths CD
JOIN CovidAnalysis..CovidVaccinations CV
    ON CD.location = CV.location
        AND CD.date = CV.date
WHERE CD.continent IS NOT NULL
ORDER BY 2, 3

SELECT *
    , (RollingPopleVaccinated/Population)*100 AS [Percent Population Vaccinated]
FROM #PercentPopulationVaccinated



--Creating views to be used in a PowerBI project
--Creating a view to store data for later visualisations
CREATE VIEW DailyRollingVaccinations AS
SELECT
    CD.continent
    , CD.location
    , CD.date
	, CD.population
    , CV.new_vaccinations
    , SUM(CV.new_vaccinations) OVER (PARTITION BY CD.location ORDER BY CD.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Rolling Vaccionations]
FROM CovidAnalysis..CovidDeaths CD
JOIN CovidAnalysis..CovidVaccinations CV
    ON CD.location = CV.location
        AND CD.date = CV.date
WHERE CD.continent IS NOT NULL



CREATE VIEW WorldDeathPercentage AS
SELECT 
	SUM(new_cases) as total_cases
	, SUM(cast(new_deaths as int)) as total_deaths
	, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
FROM CovidAnalysis..CovidDeaths
WHERE continent IS NOT NULL 



CREATE VIEW ContinentTotalDeathCount AS
SELECT 
	location
	, SUM(cast(new_deaths as int)) as TotalDeathCount
FROM CovidAnalysis..CovidDeaths
WHERE continent IS NULL
	AND location NOT IN ('World', 'European Union', 'International')
GROUP BY location



CREATE VIEW CountryPercentPopulationInfected AS
SELECT 
	location
	, population
	, MAX(total_cases) as HighestInfectionCount
	, Max((total_cases/population))*100 as PercentPopulationInfected
FROM CovidAnalysis..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population



CREATE VIEW CountryDailyRollingInfections AS
SELECT 
	location
	, population
	, date
	, MAX(total_cases) as HighestInfectionCount
	, Max((total_cases/population))*100 as PercentPopulationInfected
FROM CovidAnalysis..CovidDeaths
GROUP BY location, population, date