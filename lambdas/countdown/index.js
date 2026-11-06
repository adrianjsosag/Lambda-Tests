exports.handler = async (event) => {
    const now = new Date();
    // Año en UTC: con getFullYear() (hora local) fuera de AWS el 1 de enero daba valores negativos
    const nextYear = now.getUTCFullYear() + 1;
    const newYearDate = new Date(Date.UTC(nextYear, 0, 1)); // 1 de enero 00:00 UTC
    
    // Calcular la diferencia en milisegundos
    const diffMs = newYearDate - now;
    
    // Convertir a días, horas, minutos y segundos
    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((diffMs % (1000 * 60)) / 1000);
    
    const countdownMessage = `Faltan ${days} días, ${hours} horas, ${minutes} minutos y ${seconds} segundos para Año Nuevo 🎉`;
    
    console.log(countdownMessage);
    
    return {
        statusCode: 200,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
            target_year: nextYear,
            time_remaining: { days, hours, minutes, seconds },
            message: countdownMessage 
        })
    };
};