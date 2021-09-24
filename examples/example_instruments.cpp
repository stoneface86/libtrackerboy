

#include "trackerboy/data/Module.hpp"
#include "trackerboy/InstrumentPreview.hpp"
#include "trackerboy/Synth.hpp"
#include "trackerboy/apu/DefaultApu.hpp"

#include "Wav.hpp"

#include <memory>

using namespace trackerboy;

constexpr unsigned SAMPLERATE = 48000;

int main() {

    Module mod;

    auto &itable = mod.instrumentTable();

    
    // sample instrument with a looping arp sequence
    auto &inst = itable.insert();
    inst.setEnvelope(0xF4);
    inst.setEnvelopeEnable(true);
    {
        auto &seq = inst.sequence(Instrument::SEQUENCE_ARP);
        auto &seqdata = seq.data();
        seqdata = { 0, 0, 7, 7, 4, 4, 11, 11 };
        seq.setLoop(0);
    }
    {
        auto &seq = inst.sequence(Instrument::SEQUENCE_TIMBRE);
        auto &seqdata = seq.data();
        seqdata = { 0 };
    }


    Wav wav("example_instrument.wav", 2, SAMPLERATE);

    DefaultApu apu;
    Synth synth(apu, SAMPLERATE);
    RuntimeContext rc(apu, itable, mod.waveformTable());

    auto buffersize = synth.framesize();
    auto buffer = std::make_unique<float[]>(buffersize * 2);

    InstrumentPreview preview;
    preview.setInstrument(itable.getShared(0));
    uint8_t note = 36;
    

    for (int i = 0; i != 200; ++i) {
        if (i % 50 == 0) {
            preview.play(note);
            note += 12;
        }
        
        preview.step(rc);
        synth.run();

        auto samples = apu.readSamples(buffer.get(), buffersize);
        wav.write(buffer.get(), samples);

    }


    return 0;
}
