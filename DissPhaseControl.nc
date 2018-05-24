/*interface DissPhaseControl
{
    command error_t startInit();
    event void startInitDone(error_t error);

    command error_t startDiss();
    event void startDissDone(error_t error);

    command error_t stop();
    event void stopDone(error_t error);
}*/
//
interface DissPhaseControl
{
    event error_t startInitDone();
    event error_t startDissDone();
    event error_t stopDone();
}